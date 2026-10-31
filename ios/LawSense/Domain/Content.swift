import Foundation

struct ArticleReference: Codable, Hashable, Sendable {
    let lawId: String
    let lawVersionId: String
    let editionId: String
    let articleKey: String
    var identity: String { [lawId, lawVersionId, editionId, articleKey].map { "\($0.utf8.count):\($0)" }.joined() }
}

struct Law: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
}

struct Article: Codable, Identifiable, Hashable, Sendable {
    let reference: ArticleReference
    let number: String
    let title: String
    let text: String
    let source: String
    let versionLabel: String
    var reviewedAt: String? = nil
    var id: String { reference.identity }
}

struct KnowledgeCard: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let revision: Int
    let lawId: String
    let topic: String
    let title: String
    let conclusion: String
    let story: String
    let points: [String]
    let misconception: String
    let articleRefs: [ArticleReference]
    let questionId: String
    let minutes: Int
    var source: String? = nil
    var reviewedAt: String? = nil
    var category: String? = nil
    var scenarioLabel: String? = nil
    var questionIds: [String]? = nil
    var pointReferences: [[ArticleReference]]? = nil
    var consequences: [ConsequenceQuote]? = nil
    var quizIDs: [String] { questionIds ?? [questionId] }
}

struct QuizOption: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let text: String
}

struct Question: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let revision: Int
    let prompt: String
    let options: [QuizOption]
    let correctOptionId: String
    let explanation: String
    let cardId: String
    let articleRefs: [ArticleReference]
    var cardIds: [String]? = nil
    var reviewedAt: String? = nil
    var linkedCardIDs: [String] { cardIds ?? [cardId] }
    var identity: String { "\(id.utf8.count):\(id):\(revision)" }
}

struct ContentCatalog: Codable, Sendable {
    let schemaVersion: Int
    let packageId: String
    let kind: String
    let laws: [Law]
    let articles: [Article]
    let cards: [KnowledgeCard]
    let questions: [Question]
    var coursePlan: CoursePlan? = nil
    var searchAliases: [ContentAlias]? = nil
    var migrations: [ContentMigration]? = nil

    func article(_ ref: ArticleReference) -> Article? { articles.first { $0.reference == ref } }
    func card(_ id: String) -> KnowledgeCard? { cards.first { $0.id == id } }
    func question(_ id: String) -> Question? { questions.first { $0.id == id } }
}

enum ContentError: Error, LocalizedError, Equatable {
    case invalid(String)
    var errorDescription: String? {
        if case .invalid(let detail) = self { return "内容无法加载：\(detail)" }
        return nil
    }
}

struct ConsequenceQuote: Codable, Hashable, Sendable { let quote: String; let articleRef: ArticleReference }
struct ContentAlias: Codable, Sendable { let term: String; let pinyin: String; let initials: String; let lawId: String; let isLaw: Bool }
struct ContentMigration: Codable, Sendable { let kind: String; let oldId: String; let newIds: [String]; let change: String; let reason: String }
