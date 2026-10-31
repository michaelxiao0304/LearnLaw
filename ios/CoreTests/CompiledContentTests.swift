import Foundation
import CryptoKit
import Testing
@testable import LawSenseCore

struct CompiledContentTests {
    @Test func compilerOutputRetainsMultipleQuestionsAndApprovedIndex() throws {
        let root = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let data = try Data(contentsOf: root.appendingPathComponent("approved-catalog.json"))
        let catalog = try JSONDecoder().decode(ContentCatalog.self, from: data)
        try ApprovedContentValidator.validate(catalog)
        #expect(catalog.questions.count == 300 && catalog.cards.count == 100)
        #expect(catalog.cards.first?.quizIDs.count == 3)
        let prepared = try JSONDecoder().decode(PreparedSearchIndex.self, from: Data(contentsOf: root.appendingPathComponent("search-index.json")))
        #expect(prepared.sourceDigest == SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
        let search = ContentSearch(catalog: catalog, prepared: prepared)
        #expect(search.articles(query: "第一条").count == 3)
        #expect(search.articles(query: "ＭＦＤ").first?.reference.lawId == "civil")
        #expect(search.articles(query: "合成结构测试").count == 3)
        #expect(search.articles(query: "合成不连续结构测试").isEmpty)
    }
    @Test func incompleteFormalCatalogCannotLoad() {
        #expect(throws: ContentError.self) { try ApprovedContentValidator.validate(ContentValidationTests.fixture(kind: "approved")) }
    }
}
