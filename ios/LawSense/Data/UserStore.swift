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
    static var schemas: [any VersionedSchema.Type] { [UserSchemaV1.self, UserSchemaV2.self, UserSchemaV3.self, UserSchemaV4.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: UserSchemaV1.self, toVersion: UserSchemaV2.self), .lightweight(fromVersion: UserSchemaV2.self, toVersion: UserSchemaV3.self), .lightweight(fromVersion: UserSchemaV3.self, toVersion: UserSchemaV4.self)] }
}

struct SavedBookmark: Identifiable, Sendable {
    let id: String
    let kind: String
    let target: String
    let title: String
    let revision: Int
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
    private let storeURL: URL?
    let isReadOnly: Bool
    private var nextSequence: Int64 = 1
    private var assignments: [String: UserSchemaV2.DailyRecord] = [:]
    private var answersByID: [String: SavedAttempt] = [:]
    private var wrongHistory: Set<String> = []
    private var pendingReview: Set<String> = []
    var recordsStudyDays = true
    private(set) var sessions: [String: CourseSession] = [:]
    private(set) var levelPasses: Set<String> = []
    private(set) var bookmarks: [SavedBookmark] = []
    private(set) var attempts: [SavedAttempt] = []
    private(set) var completed: Set<String> = []
    private(set) var studyDays: Set<String> = []

    static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: UserSchemaV4.self)
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        if !configuration.isStoredInMemoryOnly { try StoreBackup.ensureBeforeOpening(configuration.url) }
        return try ModelContainer(for: schema, migrationPlan: UserMigrationPlan.self, configurations: configuration)
    }

    init(container: ModelContainer) throws {
        let context = ModelContext(container)
        self.context = context
        storeURL = container.configurations.first(where: { !$0.isStoredInMemoryOnly })?.url
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
        storeURL = nil
        isReadOnly = true
    }

    func clearLearning() throws {
        let context = try writableContext()
        let answers = try context.fetch(FetchDescriptor<UserSchemaV2.AttemptRecord>())
        let completions = try context.fetch(FetchDescriptor<UserSchemaV2.CompletionRecord>())
        let days = try context.fetch(FetchDescriptor<UserSchemaV2.DailyRecord>())
        let courseSessions = try context.fetch(FetchDescriptor<UserSchemaV3.CourseSessionRecord>())
        let passes = try context.fetch(FetchDescriptor<UserSchemaV3.LevelPassRecord>())
        for value in courseSessions { context.delete(value) }
        for value in passes { context.delete(value) }
        for value in answers { context.delete(value) }
        for value in completions { context.delete(value) }
        for value in days { context.delete(value) }
        try commit()
        attempts.removeAll(); answersByID.removeAll(); completed.removeAll(); studyDays.removeAll()
        assignments.removeAll(); wrongHistory.removeAll(); pendingReview.removeAll()
        nextSequence = 1; sessions.removeAll(); levelPasses.removeAll()
        if let storeURL { try StoreBackup.remove(for: storeURL) }
    }

    func clearBookmarks() throws {
        let context = try writableContext()
        let records = try context.fetch(FetchDescriptor<UserSchemaV4.BookmarkRecord>())
        for value in records { context.delete(value) }
        try commit()
        bookmarks.removeAll()
        if let storeURL { try StoreBackup.remove(for: storeURL) }
    }

    private func writableContext() throws -> ModelContext {
        guard let context else { throw ContentError.invalid("当前为只读模式，学习记录尚不可保存。请重试打开用户数据库。") }
        return context
    }

    func isBookmarked(kind: String, target: String) -> Bool { bookmarks.contains { $0.kind == kind && $0.target == target } }

    func toggleBookmark(kind: String, target: String, title: String, revision: Int = 0) throws {
        let context = try writableContext()
        let key = "\(kind):\(target)"
        let query = FetchDescriptor<UserSchemaV4.BookmarkRecord>(predicate: #Predicate { $0.key == key })
        if let existing = try context.fetch(query).first {
            context.delete(existing)
            try commit()
            bookmarks.removeAll { $0.id == key }
        } else {
            context.insert(UserSchemaV4.BookmarkRecord(key: key, kind: kind, target: target, title: title, revision: revision))
            try commit()
            bookmarks.insert(SavedBookmark(id: key, kind: kind, target: target, title: title, revision: revision), at: 0)
        }
    }

    @discardableResult
    func submit(id: String, question: Question, selected: String, mode: String, date: Date = .now, zone: TimeZone = .current) throws -> SavedAttempt {
        if let existing = answersByID[id] { return existing }
        guard question.options.contains(where: { $0.id == selected }) else { throw ContentError.invalid("所选答案不存在") }
        let context = try writableContext()
        let record = UserSchemaV2.AttemptRecord(id: id, question: question, selected: selected, mode: mode, date: date, zone: zone)
        if !recordsStudyDays { record.day = "" }
        record.sequence = nextSequence
        context.insert(record)
        try commit()
        nextSequence += 1
        let saved = snapshot(record)
        attempts.append(saved); answersByID[id] = saved
        if !saved.day.isEmpty { studyDays.insert(saved.day) }
        updateReview(saved)
        return saved
    }

    func complete(card: KnowledgeCard, question: Question, attemptID: String, date: Date = .now, zone: TimeZone = .current) throws {
        guard attempts.contains(where: { $0.id == attemptID && $0.questionId == question.id && $0.revision == question.revision }),
              question.linkedCardIDs.contains(card.id) else { throw ContentError.invalid("请先完成本卡测验并查看解析") }
        let key = "\(card.id):\(card.revision)"
        guard !completed.contains(key) else { return }
        let context = try writableContext()
        let completion = UserSchemaV2.CompletionRecord(key: key, date: date, zone: zone)
        if !recordsStudyDays { completion.day = "" }
        context.insert(completion)
        try commit()
        completed.insert(key)
        if recordsStudyDays { studyDays.insert(LearningRules.dayKey(date, timeZone: zone)) }
    }

    func prepareDailyQueue(catalog: ContentCatalog, date: Date = .now, zone: TimeZone = .current) throws {
        guard let context else { return }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        var additions: [UserSchemaV2.DailyRecord] = []
        for offset in 0..<30 {
            guard let target = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            let day = LearningRules.dayKey(target, timeZone: zone)
            if let saved = assignments[day] {
                if let question = catalog.question(saved.questionId), question.revision == saved.revision { continue }
                if answersByID["daily:\(day):\(saved.questionId.utf8.count):\(saved.questionId):\(saved.revision)"] != nil { continue }
                if let id = LearningRules.questionID(day: day, ids: catalog.questions.map(\.id)), let replacement = catalog.question(id) {
                    saved.questionId = replacement.id; saved.revision = replacement.revision; saved.packageId = catalog.packageId
                }
                continue
            }
            guard let id = LearningRules.questionID(day: day, ids: catalog.questions.map(\.id)),
                  let question = catalog.question(id) else { continue }
            additions.append(UserSchemaV2.DailyRecord(day: day, question: question, packageId: catalog.packageId))
        }
        for record in additions { context.insert(record) }
        guard context.hasChanges else { return }
        try commit()
        for record in additions { assignments[record.day] = record }
    }

    var scheduledDayCount: Int { assignments.count }

    func daily(catalog: ContentCatalog, date: Date = .now, zone: TimeZone = .current) throws -> Question? {
        let day = LearningRules.dayKey(date, timeZone: zone)
        if let saved = assignments[day] {
            if let question = catalog.question(saved.questionId), question.revision == saved.revision { return question }
            if attempts.contains(where: { $0.id == "daily:\(day):\(saved.questionId.utf8.count):\(saved.questionId):\(saved.revision)" }) {
                throw ContentError.invalid("已作答的今日题版本已更新，历史保留；可前往练习场学习当前内容。")
            }
            guard let id = LearningRules.questionID(day: day, ids: catalog.questions.map(\.id)), let replacement = catalog.question(id) else { return nil }
            saved.questionId = replacement.id; saved.revision = replacement.revision; saved.packageId = catalog.packageId
            try commit()
            return replacement
        }
        guard let id = LearningRules.questionID(day: day, ids: catalog.questions.map(\.id)), let question = catalog.question(id) else { return nil }
        if let context {
            let record = UserSchemaV2.DailyRecord(day: day, question: question, packageId: catalog.packageId)
            context.insert(record); try commit(); assignments[day] = record
        }
        return question
    }

    func passedLevels(in plan: CoursePlan) -> Set<String> {
        Set(plan.levels.filter { levelPasses.contains(CourseSession.key(planID: plan.id, levelID: $0.id)) }.map(\.id))
    }

    func startCourse(_ level: CourseLevel, plan: CoursePlan, catalog: ContentCatalog, restart: Bool = false) throws -> CourseSession {
        guard plan.isUnlocked(level, passed: passedLevels(in: plan)) else { throw ContentError.invalid("请先完成前置关卡") }
        let key = CourseSession.key(planID: plan.id, levelID: level.id)
        if !restart, let saved = sessions[key] { return saved }
        let versions = try level.questionIDs.map { id in
            guard let question = catalog.question(id) else { throw ContentError.invalid("关卡题目缺失") }
            return QuestionVersion(id: id, revision: question.revision)
        }
        let session = CourseSession(id: UUID().uuidString, planID: plan.id, levelID: level.id, questions: versions, position: 0, selected: nil)
        try saveSession(session)
        return session
    }

    func saveSession(_ session: CourseSession) throws {
        let context = try writableContext()
        try stageSession(session, context: context)
        try commit()
        sessions[session.key] = session
    }

    private func stageSession(_ session: CourseSession, context: ModelContext) throws {
        guard !session.id.isEmpty, !session.questions.isEmpty,
              (0...session.questions.count).contains(session.position) else { throw ContentError.invalid("学习会话格式无效") }
        let key = session.key
        let encoded = try JSONEncoder().encode(session)
        let query = FetchDescriptor<UserSchemaV3.CourseSessionRecord>(predicate: #Predicate { $0.key == key })
        if let record = try context.fetch(query).first { record.encoded = encoded }
        else { context.insert(UserSchemaV3.CourseSessionRecord(key: key, encoded: encoded)) }
    }

    func advanceCourse(_ session: CourseSession) throws -> CourseSession {
        guard let active = sessions[session.key], active.id == session.id else { throw ContentError.invalid("学习会话已更新，请重新打开关卡") }
        if active.position > session.position { return active }
        guard !session.finished, session.questions.indices.contains(session.position) else { return session }
        let version = session.questions[session.position]
        guard attempts.contains(where: { $0.id == session.attemptID(at: session.position) && $0.questionId == version.id && $0.revision == version.revision }) else { throw ContentError.invalid("请先提交答案并查看解析") }
        var next = session; next.position += 1; next.selected = nil
        if next.finished {
            guard next.questions.enumerated().allSatisfy({ index, question in
                guard let answer = answersByID[next.attemptID(at: index)] else { return false }
                return answer.questionId == question.id && answer.revision == question.revision
            }) else { throw ContentError.invalid("关卡记录不完整，无法计入成绩") }
        }
        let context = try writableContext()
        try stageSession(next, context: context)
        let correct = score(next)
        let passed = next.finished && LearningRules.isPassing(correct: correct, total: next.questions.count)
        if passed && !levelPasses.contains(next.key) {
            context.insert(UserSchemaV3.LevelPassRecord(key: next.key, correct: correct, total: next.questions.count))
        }
        try commit()
        sessions[next.key] = next
        if passed { levelPasses.insert(next.key) }
        return next
    }

    func score(_ session: CourseSession) -> Int {
        session.questions.indices.filter { answersByID[session.attemptID(at: $0)]?.correct == true }.count
    }

    func unavailableWrongCount(in catalog: ContentCatalog) -> Int {
        wrongHistory.subtracting(Set(catalog.questions.map(\.identity))).count
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
        bookmarks = try context.fetch(FetchDescriptor<UserSchemaV4.BookmarkRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
            .map { SavedBookmark(id: $0.key, kind: $0.kind, target: $0.target, title: $0.title, revision: $0.revision) }
        let records = try context.fetch(FetchDescriptor<UserSchemaV2.AttemptRecord>(sortBy: [SortDescriptor(\.sequence)]))
        attempts = records.map(snapshot)
        answersByID = Dictionary(uniqueKeysWithValues: attempts.map { ($0.id, $0) })
        nextSequence = (records.last?.sequence ?? 0) + 1
        for attempt in attempts { updateReview(attempt) }
        let completions = try context.fetch(FetchDescriptor<UserSchemaV2.CompletionRecord>())
        completed = Set(completions.map(\.key))
        studyDays = Set(attempts.map(\.day)).union(completions.map(\.day)).subtracting([""])
        let savedSessions = try context.fetch(FetchDescriptor<UserSchemaV3.CourseSessionRecord>())
        for record in savedSessions {
            let session = try JSONDecoder().decode(CourseSession.self, from: record.encoded)
            guard record.key == session.key, !session.questions.isEmpty,
                  (0...session.questions.count).contains(session.position) else { throw ContentError.invalid("学习会话损坏，原记录已保留") }
            sessions[record.key] = session
        }
        levelPasses = Set(try context.fetch(FetchDescriptor<UserSchemaV3.LevelPassRecord>()).map(\.key))
        assignments = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<UserSchemaV2.DailyRecord>()).map { ($0.day, $0) })
    }
}
