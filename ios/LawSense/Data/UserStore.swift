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

enum UserSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
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
        var sequence: Int64 = 0
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
    static var schemas: [any VersionedSchema.Type] { [UserSchemaV1.self, UserSchemaV2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: UserSchemaV1.self, toVersion: UserSchemaV2.self)] }
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
    private let context: ModelContext?
    let isReadOnly: Bool
    private var nextSequence: Int64 = 1
    private var assignments: [String: UserSchemaV2.DailyRecord] = [:]
    private var wrongHistory: Set<String> = []
    private var pendingReview: Set<String> = []
    private(set) var bookmarks: [SavedBookmark] = []
    private(set) var attempts: [SavedAttempt] = []
    private(set) var completed: Set<String> = []
    private(set) var studyDays: Set<String> = []

    static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: UserSchemaV2.self)
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, migrationPlan: UserMigrationPlan.self, configurations: configuration)
    }

    init(container: ModelContainer) throws {
        let context = ModelContext(container)
        self.context = context
        isReadOnly = false
        context.autosaveEnabled = false
        let old = try context.fetch(FetchDescriptor<UserSchemaV2.AttemptRecord>(sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.id)]))
        var sequence = (old.map(\.sequence).max() ?? 0) + 1
        for record in old where record.sequence == 0 { record.sequence = sequence; sequence += 1 }
        if context.hasChanges { try context.save() }
        try refresh()
    }

    init(readOnly: Bool) {
        precondition(readOnly)
        context = nil
        isReadOnly = true
    }

    func clearLearning() throws {
        let context = try writableContext()
        let answers = try context.fetch(FetchDescriptor<UserSchemaV2.AttemptRecord>())
        let completions = try context.fetch(FetchDescriptor<UserSchemaV2.CompletionRecord>())
        let days = try context.fetch(FetchDescriptor<UserSchemaV2.DailyRecord>())
        for value in answers { context.delete(value) }
        for value in completions { context.delete(value) }
        for value in days { context.delete(value) }
        try commit()
        attempts.removeAll(); completed.removeAll(); studyDays.removeAll()
        assignments.removeAll(); wrongHistory.removeAll(); pendingReview.removeAll()
        nextSequence = 1
    }

    func clearBookmarks() throws {
        let context = try writableContext()
        let records = try context.fetch(FetchDescriptor<UserSchemaV2.BookmarkRecord>())
        for value in records { context.delete(value) }
        try commit()
        bookmarks.removeAll()
    }

    private func writableContext() throws -> ModelContext {
        guard let context else { throw ContentError.invalid("当前为只读模式，学习记录尚不可保存。请重试打开用户数据库。") }
        return context
    }

    func isBookmarked(kind: String, target: String) -> Bool { bookmarks.contains { $0.kind == kind && $0.target == target } }

    func toggleBookmark(kind: String, target: String, title: String) throws {
        let context = try writableContext()
        let key = "\(kind):\(target)"
        let query = FetchDescriptor<UserSchemaV2.BookmarkRecord>(predicate: #Predicate { $0.key == key })
        if let existing = try context.fetch(query).first {
            context.delete(existing)
            try commit()
            bookmarks.removeAll { $0.id == key }
        } else {
            context.insert(UserSchemaV2.BookmarkRecord(key: key, kind: kind, target: target, title: title))
            try commit()
            bookmarks.insert(SavedBookmark(id: key, kind: kind, target: target, title: title), at: 0)
        }
    }

    @discardableResult
    func submit(id: String, question: Question, selected: String, mode: String, date: Date = .now, zone: TimeZone = .current) throws -> SavedAttempt {
        if let existing = attempts.first(where: { $0.id == id }) { return existing }
        guard question.options.contains(where: { $0.id == selected }) else { throw ContentError.invalid("所选答案不存在") }
        let context = try writableContext()
        let record = UserSchemaV2.AttemptRecord(id: id, question: question, selected: selected, mode: mode, date: date, zone: zone)
        record.sequence = nextSequence
        context.insert(record)
        try commit()
        nextSequence += 1
        let saved = snapshot(record)
        attempts.append(saved)
        studyDays.insert(saved.day)
        updateReview(saved)
        return saved
    }

    func complete(card: KnowledgeCard, question: Question, attemptID: String, date: Date = .now, zone: TimeZone = .current) throws {
        guard attempts.contains(where: { $0.id == attemptID && $0.questionId == question.id && $0.revision == question.revision }),
              question.cardId == card.id else { throw ContentError.invalid("请先完成本卡测验并查看解析") }
        let key = "\(card.id):\(card.revision)"
        guard !completed.contains(key) else { return }
        let context = try writableContext()
        context.insert(UserSchemaV2.CompletionRecord(key: key, date: date, zone: zone))
        try commit()
        completed.insert(key)
        studyDays.insert(LearningRules.dayKey(date, timeZone: zone))
    }

    func daily(catalog: ContentCatalog, date: Date = .now, zone: TimeZone = .current) throws -> Question? {
        let day = LearningRules.dayKey(date, timeZone: zone)
        if let saved = assignments[day] {
            guard let question = catalog.question(saved.questionId), question.revision == saved.revision else {
                throw ContentError.invalid("今日题的内容版本已更新")
            }
            return question
        }
        guard let id = LearningRules.questionID(day: day, ids: catalog.questions.map(\.id)), let question = catalog.question(id) else { return nil }
        if let context {
            let record = UserSchemaV2.DailyRecord(day: day, question: question, packageId: catalog.packageId)
            context.insert(record)
            try commit()
            assignments[day] = record
        }
        return question
    }

    func wrongQuestions(in catalog: ContentCatalog, onlyPending: Bool) -> [Question] {
        let keys = onlyPending ? pendingReview : wrongHistory
        return catalog.questions.filter { keys.contains($0.identity) }
    }

    private func updateReview(_ attempt: SavedAttempt) {
        let key = "\(attempt.questionId.utf8.count):\(attempt.questionId):\(attempt.revision)"
        if !attempt.correct { wrongHistory.insert(key); pendingReview.insert(key) }
        else if attempt.mode == "review" { pendingReview.remove(key) }
    }

    private func snapshot(_ record: UserSchemaV2.AttemptRecord) -> SavedAttempt {
        SavedAttempt(id: record.id, questionId: record.questionId, revision: record.revision, selected: record.selected, correct: record.correct, mode: record.mode, day: record.day, date: record.createdAt)
    }

    private func commit() throws {
        let context = try writableContext()
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    private func refresh() throws {
        let context = try writableContext()
        bookmarks = try context.fetch(FetchDescriptor<UserSchemaV2.BookmarkRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
            .map { SavedBookmark(id: $0.key, kind: $0.kind, target: $0.target, title: $0.title) }
        let records = try context.fetch(FetchDescriptor<UserSchemaV2.AttemptRecord>(sortBy: [SortDescriptor(\.sequence)]))
        attempts = records.map(snapshot)
        nextSequence = (records.last?.sequence ?? 0) + 1
        for attempt in attempts { updateReview(attempt) }
        let completions = try context.fetch(FetchDescriptor<UserSchemaV2.CompletionRecord>())
        completed = Set(completions.map(\.key))
        studyDays = Set(attempts.map(\.day)).union(completions.map(\.day))
        assignments = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<UserSchemaV2.DailyRecord>()).map { ($0.day, $0) })
    }
}
