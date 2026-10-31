import Testing
@testable import LawSenseCore
struct SearchTests {
    @Test(arguments: [("第一条", "1"), ("第十三条之一", "13-1"), ("264", "264"), ("一千零一", "1001")])
    func parsesArticleNumbers(input: String, expected: String) { #expect(ContentSearch.articleNumber(input) == expected) }
    @Test func combinedLawAndNumberAndMalformedNumbers() {
        let search = ContentSearch(catalog: ContentValidationTests.fixture())
        #expect(search.articles(query: "示例第一条").count == 1)
        #expect(search.articles(query: "示例第二条").isEmpty)
        #expect(ContentSearch.articleNumber("第条1第") == nil)
        #expect(ContentSearch.articleNumber("一百百") == nil)
    }
    @Test func ambiguousReviewedPinyinReturnsAllMatchingTerms() {
        let base = ContentValidationTests.fixture()
        let extra = Article(reference: ArticleReference(lawId: "demo", lawVersionId: "v1", editionId: "e1", articleKey: "2"), number: "第二条", title: "另一条", text: "其他说明", source: "test", versionLabel: "v1")
        var catalog = ContentCatalog(schemaVersion: 1, packageId: base.packageId, kind: base.kind, laws: base.laws, articles: base.articles + [extra], cards: base.cards, questions: base.questions)
        catalog.searchAliases = [
            ContentAlias(term: "演示文本", pinyin: "yanshi", initials: "ys", lawId: "demo", isLaw: false),
            ContentAlias(term: "其他说明", pinyin: "yanshi", initials: "ys", lawId: "demo", isLaw: false)
        ]
        #expect(ContentSearch(catalog: catalog).articles(query: "ys").count == 2)
    }
    @Test func keywordAliasesResolveOnceAsLiteralText() {
        let base = ContentValidationTests.fixture()
        let extra = Article(reference: ArticleReference(lawId: "demo", lawVersionId: "v1", editionId: "e1", articleKey: "2"), number: "第二条", title: "link", text: "独立条目", source: "test", versionLabel: "v1")
        var catalog = ContentCatalog(schemaVersion: 1, packageId: base.packageId, kind: base.kind, laws: base.laws, articles: base.articles + [extra], cards: base.cards, questions: base.questions)
        catalog.searchAliases = [
            ContentAlias(term: "link", pinyin: "lianjie", initials: "lj", lawId: "demo", isLaw: false),
            ContentAlias(term: "演示文本", pinyin: "link", initials: "lk", lawId: "demo", isLaw: false)
        ]
        #expect(ContentSearch(catalog: catalog).articles(query: "lj").map(\.id) == [extra.id])
    }
    @Test func exactVersionAndMissingArticleDoNotFallBack() {
        let search = ContentSearch(catalog: ContentValidationTests.fixture())
        #expect(search.articles(query: "第一条").count == 1)
        #expect(search.articles(query: "第２条").isEmpty)
        #expect(search.articles(query: "原文不存在").isEmpty)
        #expect(search.articles(query: "第一条", lawId: "other").isEmpty)
    }
}
