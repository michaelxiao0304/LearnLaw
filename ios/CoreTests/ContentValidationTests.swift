import Testing
@testable import LawSenseCore

struct ContentValidationTests {
    static let reference = ArticleReference(lawId: "demo", lawVersionId: "v1", editionId: "e1", articleKey: "1")
    static func fixture(kind: String = "development", brokenRef: Bool = false, correct: String = "yes") -> ContentCatalog {
        let ref = brokenRef ? ArticleReference(lawId: "demo", lawVersionId: "v2", editionId: "e1", articleKey: "1") : reference
        return ContentCatalog(schemaVersion: 1, packageId: "fixture", kind: kind,
            laws: [Law(id: "demo", title: "示例", subtitle: "非法律", symbol: "book")],
            articles: [Article(reference: reference, number: "第一条", title: "说明", text: "演示文本", source: "开发样例", versionLabel: "演示版")],
            cards: [KnowledgeCard(id: "card", revision: 1, lawId: "demo", topic: "示例", title: "说明", conclusion: "阅读说明", story: "示例", points: ["检查版本"], misconception: "非法律", articleRefs: [ref], questionId: "question", minutes: 1)],
            questions: [Question(id: "question", revision: 1, prompt: "是否检查版本？", options: [QuizOption(id: "yes", text: "是"), QuizOption(id: "no", text: "否")], correctOptionId: correct, explanation: "先看版本", cardId: "card", articleRefs: [ref])])
    }
    @Test func validDevelopmentFixtureLoads() throws { try DevelopmentContentValidator.validate(Self.fixture()) }
    @Test func refusesToTreatFixtureFormatAsApprovedContent() {
        #expect(throws: ContentError.self) { try DevelopmentContentValidator.validate(Self.fixture(kind: "approved")) }
    }
    @Test func exactVersionReferenceMustResolve() {
        #expect(throws: ContentError.self) { try DevelopmentContentValidator.validate(Self.fixture(brokenRef: true)) }
    }
    @Test func correctAnswerMustExist() {
        #expect(throws: ContentError.self) { try DevelopmentContentValidator.validate(Self.fixture(correct: "missing")) }
    }
}
