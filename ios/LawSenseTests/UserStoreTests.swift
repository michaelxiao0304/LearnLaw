import Foundation
import Testing
import SwiftData
@testable import LawSenseDev

@MainActor struct UserStoreTests {
    func catalog() throws -> ContentCatalog {
        let url = try #require(Bundle.main.url(forResource: "development-catalog", withExtension: "json"))
        return try JSONDecoder().decode(ContentCatalog.self, from: Data(contentsOf: url))
    }
    @Test func duplicateAnswerIsSavedExactlyOnceAndWrongAnswerAppearsInReview() throws {
        let catalog = try catalog()
        let question = try #require(catalog.questions.first)
        let store = try UserStore(container: UserStore.makeContainer(inMemory: true))
        let first = try store.submit(id: "one", question: question, selected: "b", mode: "practice")
        let repeatAttempt = try store.submit(id: "one", question: question, selected: "a", mode: "practice")
        #expect(!first.correct && !repeatAttempt.correct)
        #expect(store.attempts.count == 1)
        #expect(store.wrongQuestions(in: catalog, onlyPending: true).map(\.id) == [question.id])
        try store.submit(id: "two", question: question, selected: "a", mode: "review", date: .now.addingTimeInterval(1))
        #expect(store.wrongQuestions(in: catalog, onlyPending: true).isEmpty)
        #expect(store.wrongQuestions(in: catalog, onlyPending: false).count == 1)
    }
    @Test func invalidOptionAndPrematureCompletionDoNotWrite() throws {
        let catalog = try catalog()
        let question = try #require(catalog.questions.first)
        let card = try #require(catalog.card(question.cardId))
        let store = try UserStore(container: UserStore.makeContainer(inMemory: true))
        #expect(throws: ContentError.self) { try store.submit(id: "bad", question: question, selected: "missing", mode: "practice") }
        #expect(throws: ContentError.self) { try store.complete(card: card, question: question, attemptID: "missing") }
        #expect(store.attempts.isEmpty && store.completed.isEmpty)
    }
    @Test func bookmarkAndAttemptsSurviveReopeningStore() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        // SwiftData may retain SQLite handles beyond ARC scopes. The test runner
        // cleans its isolated temporary container after the host process exits.
        let database = url.appendingPathComponent("test.store")
        let catalog = try catalog()
        let question = try #require(catalog.questions.first)
        let card = try #require(catalog.card(question.cardId))
        try autoreleasepool {
            let store = try UserStore(container: UserStore.makeContainer(url: database))
            try store.toggleBookmark(kind: "card", target: card.id, title: card.title)
            try store.submit(id: "durable", question: question, selected: "b", mode: "practice")
            try store.complete(card: card, question: question, attemptID: "durable")
        }
        try autoreleasepool {
        let reopened = try UserStore(container: UserStore.makeContainer(url: database))
        #expect(reopened.isBookmarked(kind: "card", target: card.id))
        #expect(reopened.attempts.count == 1)
        #expect(reopened.completed.contains("\(card.id):\(card.revision)"))
        try reopened.toggleBookmark(kind: "card", target: card.id, title: card.title)
        #expect(reopened.bookmarks.isEmpty)
        }
    }
    @Test func todayAssignmentSurvivesRepeatedCalls() throws {
        let catalog = try catalog()
        let store = try UserStore(container: UserStore.makeContainer(inMemory: true))
        let date = Date(timeIntervalSince1970: 1_793_400_000)
        let first = try #require(try store.daily(catalog: catalog, date: date))
        let second = try #require(try store.daily(catalog: catalog, date: date))
        #expect(first == second)
    }
}
