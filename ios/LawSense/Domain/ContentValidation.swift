import Foundation

enum DevelopmentContentValidator {
    static func validate(_ catalog: ContentCatalog) throws {
        guard catalog.schemaVersion == 1, catalog.kind == "development", !catalog.packageId.isEmpty else {
            throw ContentError.invalid("开发样例格式或类型不受支持")
        }
        try unique(catalog.laws.map(\.id), "篇目")
        try unique(catalog.articles.map(\.id), "条文")
        try unique(catalog.cards.map(\.id), "卡片")
        try unique(catalog.questions.map(\.id), "题目")
        let laws = Set(catalog.laws.map(\.id))
        let refs = Set(catalog.articles.map(\.reference))
        for article in catalog.articles {
            guard laws.contains(article.reference.lawId), !article.text.isEmpty, !article.source.isEmpty,
                  !article.reference.articleKey.isEmpty, !article.reference.editionId.isEmpty else {
                throw ContentError.invalid("条文 \(article.id) 的来源或篇目缺失")
            }
        }
        for card in catalog.cards {
            try references(card.articleRefs, in: refs)
            guard laws.contains(card.lawId), card.revision > 0, !card.title.isEmpty, !card.points.isEmpty,
                  catalog.question(card.questionId)?.cardId == card.id else {
                throw ContentError.invalid("卡片 \(card.id) 的题目关联无效")
            }
        }
        for question in catalog.questions {
            try references(question.articleRefs, in: refs)
            try unique(question.options.map(\.id), "选项")
            guard question.revision > 0, !question.prompt.isEmpty, !question.explanation.isEmpty,
                  question.options.count >= 2,
                  question.options.contains(where: { $0.id == question.correctOptionId }),
                  catalog.card(question.cardId)?.questionId == question.id else {
                throw ContentError.invalid("题目 \(question.id) 的答案或卡片关联无效")
            }
        }
    }

    private static func unique(_ ids: [String], _ label: String) throws {
        guard !ids.isEmpty, ids.allSatisfy({ !$0.isEmpty }), Set(ids).count == ids.count else {
            throw ContentError.invalid("\(label) ID 为空或重复")
        }
    }

    private static func references(_ values: [ArticleReference], in refs: Set<ArticleReference>) throws {
        guard !values.isEmpty, values.allSatisfy({ refs.contains($0) }) else {
            throw ContentError.invalid("引用无法匹配精确版本的条文")
        }
    }
}
