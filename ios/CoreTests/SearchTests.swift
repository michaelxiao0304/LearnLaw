import Testing
@testable import LawSenseCore
struct SearchTests {
    @Test(arguments: [("第一条", "1"), ("第十三条之一", "13-1"), ("264", "264"), ("一千零一", "1001")])
    func parsesArticleNumbers(input: String, expected: String) { #expect(ContentSearch.articleNumber(input) == expected) }
    @Test func exactVersionAndMissingArticleDoNotFallBack() {
        let search = ContentSearch(catalog: ContentValidationTests.fixture())
        #expect(search.articles(query: "第一条").count == 1)
        #expect(search.articles(query: "第２条").isEmpty)
        #expect(search.articles(query: "原文不存在").isEmpty)
        #expect(search.articles(query: "第一条", lawId: "other").isEmpty)
    }
}
