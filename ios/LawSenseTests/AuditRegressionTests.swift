import Foundation
import SwiftData
import Testing
@testable import LawSenseDev

/// Audit-only regressions: these intentionally fail on the reviewed aeb1568 app.
/// The implementation is unchanged; remove this comment when fixing the behavior.
@MainActor struct AuditRegressionTests {
    @Test func successfulReviewAfterClockRollbackClearsPending() throws {
        let catalog = try UserStoreTests().catalog()
        let question = try #require(catalog.questions.first)
        let store = try UserStore(container: UserStore.makeContainer(inMemory: true))
        let now = Date(timeIntervalSince1970: 1_793_400_000)
        try store.submit(id: "wrong", question: question, selected: "b", mode: "practice", date: now)
        // User corrects the device clock, then successfully reviews the same question.
        try store.submit(id: "review", question: question, selected: "a", mode: "review", date: now.addingTimeInterval(-3600))
        #expect(store.wrongQuestions(in: catalog, onlyPending: true).isEmpty)
    }

    @Test func newMistakeAfterClockRollbackReopensPending() throws {
        let catalog = try UserStoreTests().catalog()
        let question = try #require(catalog.questions.first)
        let store = try UserStore(container: UserStore.makeContainer(inMemory: true))
        let now = Date(timeIntervalSince1970: 1_793_400_000)
        try store.submit(id: "wrong", question: question, selected: "b", mode: "practice", date: now)
        try store.submit(id: "review", question: question, selected: "a", mode: "review", date: now.addingTimeInterval(3600))
        #expect(store.wrongQuestions(in: catalog, onlyPending: true).isEmpty)
        // A new mistake occurs after a backwards wall-clock adjustment.
        try store.submit(id: "wrong-again", question: question, selected: "b", mode: "practice", date: now.addingTimeInterval(1800))
        #expect(store.wrongQuestions(in: catalog, onlyPending: true).map(\.id) == [question.id])
    }
}
