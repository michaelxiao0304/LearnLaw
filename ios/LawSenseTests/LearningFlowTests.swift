import Foundation
import SwiftData
import Testing
@testable import LawSenseDev

@MainActor struct LearningFlowTests {
    func plan(_ catalog: ContentCatalog) -> CoursePlan {
        CoursePlan(id: "test-plan", levels: LearningRank.allCases.enumerated().map { index, rank in
            CourseLevel(id: rank.rawValue, title: rank.title, rank: rank,
                prerequisiteIDs: index == 0 ? [] : [LearningRank.allCases[index - 1].rawValue],
                questionIDs: Array(catalog.questions.prefix(2).map(\.id)))
        })
    }
    @Test func dailyQueueIsThirtyCalendarDaysAndIdempotent() throws {
        let catalog = try UserStoreTests().catalog()
        let store = try UserStore(container: UserStore.makeContainer(inMemory: true))
        let date = Date(timeIntervalSince1970: 1_793_400_000)
        try store.prepareDailyQueue(catalog: catalog, date: date, zone: .gmt)
        #expect(store.scheduledDayCount == 30)
        let first = try store.daily(catalog: catalog, date: date, zone: .gmt)
        try store.prepareDailyQueue(catalog: catalog, date: date, zone: .gmt)
        #expect(store.scheduledDayCount == 30)
        #expect(try store.daily(catalog: catalog, date: date, zone: .gmt) == first)
        try store.prepareDailyQueue(catalog: catalog, date: date.addingTimeInterval(86400), zone: .gmt)
        #expect(store.scheduledDayCount == 31)
    }
    @Test func disablingStudyDatesRetainsFunctionalAnswersWithoutNewStreakDays() throws {
        let catalog = try UserStoreTests().catalog()
        let question = try #require(catalog.questions.first)
        let card = try #require(catalog.card(question.cardId))
        let store = try UserStore(container: UserStore.makeContainer(inMemory: true))
        store.recordsStudyDays = false
        try store.submit(id: "no-date", question: question, selected: "b", mode: "practice")
        try store.complete(card: card, question: question, attemptID: "no-date")
        #expect(store.studyDays.isEmpty)
        #expect(store.attempts.count == 1 && store.completed.count == 1)
        #expect(store.wrongQuestions(in: catalog, onlyPending: true).count == 1)
    }
    @Test func courseRequiresAnswersAndPassingBeforeUnlockingNextLevel() throws {
        let catalog = try UserStoreTests().catalog(); let plan = plan(catalog)
        let store = try UserStore(container: UserStore.makeContainer(inMemory: true))
        #expect(throws: ContentError.self) { try store.startCourse(plan.levels[1], plan: plan, catalog: catalog) }
        var session = try store.startCourse(plan.levels[0], plan: plan, catalog: catalog)
        #expect(throws: ContentError.self) { try store.advanceCourse(session) }
        for index in session.questions.indices {
            let question = try #require(catalog.question(session.questions[index].id))
            try store.submit(id: session.attemptID(at: index), question: question, selected: question.correctOptionId, mode: "course")
            let before = session
            session = try store.advanceCourse(session)
            #expect(try store.advanceCourse(before).position == session.position)
        }
        #expect(session.finished)
        #expect(plan.rank(passed: store.passedLevels(in: plan)) == .bronze)
        #expect(try store.startCourse(plan.levels[1], plan: plan, catalog: catalog).position == 0)
        try store.clearLearning()
        #expect(store.sessions.isEmpty && store.levelPasses.isEmpty)
    }
    @Test func versionTwoMigrationAndSelectionResumePreserveData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("course.store")
        let catalog = try UserStoreTests().catalog(); let plan = plan(catalog)
        try autoreleasepool {
            let schema = Schema(versionedSchema: UserSchemaV2.self)
            let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: config)
            let context = ModelContext(container)
            context.insert(UserSchemaV2.BookmarkRecord(key: "old", kind: "card", target: "old", title: "旧收藏"))
            try context.save()
        }
        try autoreleasepool {
            let store = try UserStore(container: UserStore.makeContainer(url: url))
            var session = try store.startCourse(plan.levels[0], plan: plan, catalog: catalog)
            session.selected = "b"; try store.saveSession(session)
        }
        try autoreleasepool {
            let store = try UserStore(container: UserStore.makeContainer(url: url))
            let session = try store.startCourse(plan.levels[0], plan: plan, catalog: catalog)
            #expect(session.selected == "b" && session.position == 0)
            #expect(store.bookmarks.count == 1)
        }
    }
}
