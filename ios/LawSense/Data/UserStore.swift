import Foundation
import SwiftData
import Observation

enum UserSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [BookmarkRecord.self, AttemptRecord.self, CompletionRecord.self, DailyRecord.self] }

    @Model final class BookmarkRecord {
        @Attribute(.unique) var key: String
        var kind: String
        var target: String
        var title: String
        var createdAt: Date
        init(key: String, kind: String, target: String, title: String) {
            self.key = key; self.kind = kind; self.target = target; self.title = title; createdAt = .now
        }
    }
    @Model final class AttemptRecord {
        @Attribute(.unique) var id: String
        var questionId: String
        var revision: Int
        var selected: String
        var correct: Bool
        var mode: String
        var day: String
        var timeZone: String
        var createdAt: Date
        init(id: String, question: Question, selected: String, mode: String, date: Date, zone: TimeZone) {
            self.id = id; questionId = question.id; revision = question.revision
            self.selected = selected; correct = selected == question.correctOptionId
            self.mode = mode; day = LearningRules.dayKey(date, timeZone: zone)
            timeZone = zone.identifier; createdAt = date
        }
    }
    @Model final class CompletionRecord {
        @Attribute(.unique) var key: String
        var completedAt: Date
        var day: String
        init(key: String, date: Date, zone: TimeZone) {
            self.key = key; completedAt = date; day = LearningRules.dayKey(date, timeZone: zone)
        }
    }
    @Model final class DailyRecord {
        @Attribute(.unique) var day: String
        var questionId: String
        var revision: Int
        var packageId: String
        init(day: String, question: Question, packageId: String) {
            self.day = day; questionId = question.id; revision = question.revision; self.packageId = packageId
        }
    }
}

enum UserMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [UserSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

struct SavedBookmark: Identifiable, Sendable {
    let id: String
    let kind: String
    let target: String
    let title: String
}
struct SavedAttempt: Identifiable, Sendable {
    let id: String
    let questionId: String
    let revision: Int
    let selected: String
    let correct: Bool
    let mode: String
    let day: String
    let date: Date
}

@MainActor @Observable final class UserStore {
    private let context: ModelContext
    private(set) var bookmarks: [SavedBookmark] = []
    private(set) var attempts: [SavedAttempt] = []
    private(set) var completed: Set<String> = []
    private(set) var studyDays: Set<String> = []

    static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: UserSchemaV1.self)
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, migrationPlan: UserMigrationPlan.self, configurations: configuration)
    }

    init(container: ModelContainer) throws {
        context = ModelContext(container)
        context.autosaveEnabled = false
        try refresh()
    }

    func isBookmarked(kind: String, target: String) -> Bool { bookmarks.contains { $0.kind == kind && $0.target == target } }

    func toggleBookmark(kind: String, target: String, title: String) throws {
        let key = "\(kind):\(target)"
        if let existing = try context.fetch(FetchDescriptor<UserSchemaV1.BookmarkRecord>()).first(where: { $0.key == key }) {
            context.delete(existing)
        } else {
            context.insert(UserSchemaV1.BookmarkRecord(key: key, kind: kind, target: target, title: title))
        }
        try commit()
    }

    @discardableResult
    func submit(id: String, question: Question, selected: String, mode: String, date: Date = .now, zone: TimeZone = .current) throws -> SavedAttempt {
        if let existing = attempts.first(where: { $0.id == id }) { return existing }
        guard question.options.contains(where: { $0.id == selected }) else { throw ContentError.invalid("所选答案不存在") }
        context.insert(UserSchemaV1.AttemptRecord(id: id, question: question, selected: selected, mode: mode, date: date, zone: zone))
        try commit()
        guard let saved = attempts.first(where: { $0.id == id }) else { throw ContentError.invalid("答案尚未保存") }
        return saved
    }

    func complete(card: KnowledgeCard, question: Question, attemptID: String, date: Date = .now, zone: TimeZone = .current) throws {
        guard attempts.contains(where: { $0.id == attemptID && $0.questionId == question.id && $0.revision == question.revision }),
              question.cardId == card.id else { throw ContentError.invalid("请先完成本卡测验并查看解析") }
        let key = "\(card.id):\(card.revision)"
        guard !completed.contains(key) else { return }
        context.insert(UserSchemaV1.CompletionRecord(key: key, date: date, zone: zone))
        try commit()
    }

    func daily(catalog: ContentCatalog, date: Date = .now, zone: TimeZone = .current) throws -> Question? {
        let day = LearningRules.dayKey(date, timeZone: zone)
        if let saved = try context.fetch(FetchDescriptor<UserSchemaV1.DailyRecord>()).first(where: { $0.day == day }) {
            guard let question = catalog.question(saved.questionId), question.revision == saved.revision else {
                throw ContentError.invalid("今日题的内容版本已更新")
            }
            return question
        }
        guard let id = LearningRules.questionID(day: day, ids: catalog.questions.map(\.id)), let question = catalog.question(id) else { return nil }
        context.insert(UserSchemaV1.DailyRecord(day: day, question: question, packageId: catalog.packageId))
        try commit()
        return question
    }

    func wrongQuestions(in catalog: ContentCatalog, onlyPending: Bool) -> [Question] {
        catalog.questions.filter { question in
            let history = attempts.filter { $0.questionId == question.id && $0.revision == question.revision }
            guard history.contains(where: { !$0.correct }) else { return false }
            guard onlyPending else { return true }
            // Only a successful review clears pending; a later mistake reopens it.
            let lastWrong = history.filter { !$0.correct }.map(\.date).max() ?? .distantPast
            let lastReview = history.filter { $0.mode == "review" && $0.correct }.map(\.date).max() ?? .distantPast
            return lastWrong >= lastReview
        }
    }

    private func commit() throws {
        do { try context.save() }
        catch { context.rollback(); throw error }
        try refresh()
    }

    private func refresh() throws {
        bookmarks = try context.fetch(FetchDescriptor<UserSchemaV1.BookmarkRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
            .map { SavedBookmark(id: $0.key, kind: $0.kind, target: $0.target, title: $0.title) }
        attempts = try context.fetch(FetchDescriptor<UserSchemaV1.AttemptRecord>(sortBy: [SortDescriptor(\.createdAt)]))
            .map { SavedAttempt(id: $0.id, questionId: $0.questionId, revision: $0.revision, selected: $0.selected, correct: $0.correct, mode: $0.mode, day: $0.day, date: $0.createdAt) }
        let completions = try context.fetch(FetchDescriptor<UserSchemaV1.CompletionRecord>())
        completed = Set(completions.map(\.key))
        studyDays = Set(attempts.map(\.day)).union(completions.map(\.day))
    }
}
