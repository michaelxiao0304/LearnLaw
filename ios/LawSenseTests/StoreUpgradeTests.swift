import Foundation
import SwiftData
import Testing
@testable import LawSenseDev

@MainActor struct StoreUpgradeTests {
    @Test func versionOneRecordsSurviveMigrationAndClockRollbackAcrossReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Do not unlink live SQLite files; simulator test-container cleanup is external.
        let url = directory.appendingPathComponent("upgrade.store")
        let catalog = try UserStoreTests().catalog()
        let question = try #require(catalog.questions.first)
        let date = Date(timeIntervalSince1970: 1_793_400_000)
        try autoreleasepool {
            let schema = Schema(versionedSchema: UserSchemaV1.self)
            let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: config)
            let context = ModelContext(container)
            context.insert(UserSchemaV1.BookmarkRecord(key: "card:legacy", kind: "card", target: "legacy", title: "旧收藏"))
            context.insert(UserSchemaV1.AttemptRecord(id: "old", question: question, selected: "b", mode: "practice", date: date, zone: .gmt))
            try context.save()
        }
        try autoreleasepool {
            let store = try UserStore(container: UserStore.makeContainer(url: url))
            #expect(store.isBookmarked(kind: "card", target: "legacy"))
            #expect(store.wrongQuestions(in: catalog, onlyPending: true).count == 1)
            try store.submit(id: "review", question: question, selected: "a", mode: "review", date: date.addingTimeInterval(-3600))
        }
        try autoreleasepool {
            let store = try UserStore(container: UserStore.makeContainer(url: url))
            #expect(store.attempts.count == 2)
            #expect(store.wrongQuestions(in: catalog, onlyPending: true).isEmpty)
            try store.submit(id: "again", question: question, selected: "b", mode: "practice", date: date.addingTimeInterval(-7200))
        }
        try autoreleasepool {
            let store = try UserStore(container: UserStore.makeContainer(url: url))
            #expect(store.attempts.count == 3)
            #expect(store.wrongQuestions(in: catalog, onlyPending: true).count == 1)
        }
    }

    @Test func clearingLearningPreservesBookmarksAndClearingBookmarksPreservesLearning() throws {
        let catalog = try UserStoreTests().catalog()
        let question = try #require(catalog.questions.first)
        let card = try #require(catalog.card(question.cardId))
        let store = try UserStore(container: UserStore.makeContainer(inMemory: true))
        try store.toggleBookmark(kind: "card", target: card.id, title: card.title)
        try store.submit(id: "answer", question: question, selected: "b", mode: "practice")
        try store.complete(card: card, question: question, attemptID: "answer")
        try store.clearLearning()
        #expect(store.attempts.isEmpty && store.completed.isEmpty && store.studyDays.isEmpty)
        #expect(store.wrongQuestions(in: catalog, onlyPending: false).isEmpty)
        #expect(store.bookmarks.count == 1)
        try store.submit(id: "new", question: question, selected: "a", mode: "practice")
        try store.clearBookmarks()
        #expect(store.bookmarks.isEmpty)
        #expect(store.attempts.count == 1)
    }

    @Test func versionThreeBookmarksMigrateAndNewBookmarkRevisionSurvivesReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("v3.store")
        try autoreleasepool {
            let schema = Schema(versionedSchema: UserSchemaV3.self)
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: configuration)
            let context = ModelContext(container)
            context.insert(UserSchemaV2.BookmarkRecord(key: "card:legacy", kind: "card", target: "legacy", title: "旧收藏"))
            try context.save()
        }
        try autoreleasepool {
            let store = try UserStore(container: UserStore.makeContainer(url: url))
            #expect(store.bookmarks.first?.revision == 0)
            try store.toggleBookmark(kind: "card", target: "new", title: "新收藏", revision: 3)
        }
        try autoreleasepool {
            let store = try UserStore(container: UserStore.makeContainer(url: url))
            #expect(store.bookmarks.first(where: { $0.target == "new" })?.revision == 3)
            #expect(store.isBookmarked(kind: "card", target: "legacy"))
        }
    }

    @Test func coherentBackupPreservesOldRecordsAndClearRemovesBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("protected.store")
        try autoreleasepool {
            let store = try UserStore(container: UserStore.makeContainer(url: url))
            try store.toggleBookmark(kind: "card", target: "old", title: "原收藏", revision: 1)
        }
        try autoreleasepool {
            let store = try UserStore(container: UserStore.makeContainer(url: url))
            let backup = StoreBackup.url(for: url)
            #expect(FileManager.default.fileExists(atPath: backup.path))
            let restored = directory.appendingPathComponent("restored.store")
            try FileManager.default.copyItem(at: backup, to: restored)
            let restoredStore = try UserStore(container: UserStore.makeContainer(url: restored))
            #expect(restoredStore.isBookmarked(kind: "card", target: "old"))
            try store.clearBookmarks()
            #expect(store.bookmarks.isEmpty)
            #expect(!FileManager.default.fileExists(atPath: backup.path))
        }
    }

    @Test func corruptStoreIsNotReplacedOrDeleted() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("corrupt.store")
        let original = Data("synthetic corrupt store".utf8)
        try original.write(to: url)
        #expect(throws: (any Error).self) { try UserStore.makeContainer(url: url) }
        #expect(try Data(contentsOf: url) == original)
        #expect(!FileManager.default.fileExists(atPath: StoreBackup.url(for: url).path))
    }

    @Test func databaseFailureDoesNotBlockContentLoading() async throws {
        let app = AppModel(makeUserStore: { throw CocoaError(.fileReadCorruptFile) })
        await app.load()
        #expect(app.loadError == nil)
        #expect(app.catalog != nil)
        #expect(app.userStorageError != nil)
        #expect(app.user?.isReadOnly == true)
        #expect(app.todayQuestion != nil)
    }

    @Test func readOnlyModeKeepsDailyReadingAvailableAndRejectsWrites() throws {
        let catalog = try UserStoreTests().catalog()
        let question = try #require(catalog.questions.first)
        let store = UserStore(readOnly: true)
        #expect(store.isReadOnly)
        #expect(try store.daily(catalog: catalog) != nil)
        #expect(throws: ContentError.self) { try store.toggleBookmark(kind: "card", target: "x", title: "x") }
        #expect(throws: ContentError.self) { try store.submit(id: "x", question: question, selected: "a", mode: "practice") }
        #expect(store.attempts.isEmpty && store.bookmarks.isEmpty)
    }
}
