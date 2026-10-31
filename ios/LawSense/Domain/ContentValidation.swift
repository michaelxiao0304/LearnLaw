import Foundation

enum DevelopmentContentValidator {
    static func validate(_ catalog: ContentCatalog) throws { try ContentValidator.validate(catalog, expectedKind: "development") }
}

enum ApprovedContentValidator {
    static func validate(_ catalog: ContentCatalog) throws {
        try ContentValidator.validate(catalog, expectedKind: "approved")
        guard Set(catalog.laws.map(\.id)) == ["criminal", "civil", "public_security"], catalog.cards.count >= 100,
              catalog.questions.count >= 300, let plan = catalog.coursePlan else { throw ContentError.invalid("正式内容规模或课程不完整") }
        for (law, minimum) in [("criminal", 40), ("civil", 45), ("public_security", 15)] {
            guard catalog.cards.filter({ $0.lawId == law }).count >= minimum else { throw ContentError.invalid("正式知识卡分布不完整") }
        }
        guard catalog.cards.allSatisfy({ $0.source?.isEmpty == false && $0.reviewedAt?.isEmpty == false && $0.pointReferences?.count == $0.points.count }),
              catalog.articles.allSatisfy({ $0.reviewedAt?.isEmpty == false }),
              catalog.questions.allSatisfy({ $0.reviewedAt?.isEmpty == false }) else { throw ContentError.invalid("正式来源或复核信息缺失") }
        try plan.validate(questionIDs: Set(catalog.questions.map(\.id)))
    }
}

enum ContentValidator {
    static func validate(_ catalog: ContentCatalog, expectedKind: String) throws {
        guard catalog.schemaVersion == 1, catalog.kind == expectedKind, !catalog.packageId.isEmpty else {
            throw ContentError.invalid("内容格式或类型不受支持")
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
                  !card.quizIDs.isEmpty, card.quizIDs.contains(card.questionId), card.quizIDs.allSatisfy({ catalog.question($0)?.linkedCardIDs.contains(card.id) == true }) else {
                throw ContentError.invalid("卡片 \(card.id) 的题目关联无效")
            }
        }
        for question in catalog.questions {
            try references(question.articleRefs, in: refs)
            try unique(question.options.map(\.id), "选项")
            guard question.revision > 0, !question.prompt.isEmpty, !question.explanation.isEmpty,
                  question.options.count >= 2,
                  question.options.contains(where: { $0.id == question.correctOptionId }),
                  !question.linkedCardIDs.isEmpty, question.linkedCardIDs.contains(question.cardId), question.linkedCardIDs.allSatisfy({ catalog.card($0)?.quizIDs.contains(question.id) == true }) else {
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
