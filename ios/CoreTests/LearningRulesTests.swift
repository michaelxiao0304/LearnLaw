import Foundation
import Testing
@testable import LawSenseCore

struct LearningRulesTests {
    @Test func dailySelectionIsStableRegardlessOfInputOrder() throws {
        let result = try #require(LearningRules.questionID(day: "2026-10-31", ids: ["a", "b", "c"]))
        #expect(result == LearningRules.questionID(day: "2026-10-31", ids: ["c", "a", "b"]))
        #expect(["a", "b", "c"].contains(result))
        #expect(LearningRules.questionID(day: "2026-10-31", ids: []) == nil)
    }

    @Test func localDateUsesCalendarNotUTC() throws {
        let date = try #require(ISO8601DateFormatter().date(from: "2026-10-31T23:30:00Z"))
        #expect(LearningRules.dayKey(date, timeZone: try #require(TimeZone(identifier: "Asia/Shanghai"))) == "2026-11-01")
        #expect(LearningRules.dayKey(date, timeZone: try #require(TimeZone(identifier: "America/Los_Angeles"))) == "2026-10-31")
    }

    @Test func streakKeepsYesterdayAndCrossesLeapDay() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2024-03-01T12:00:00Z"))
        let zone = try #require(TimeZone(secondsFromGMT: 0))
        #expect(LearningRules.streak(days: ["2024-02-28", "2024-02-29"], now: now, timeZone: zone) == 2)
        #expect(LearningRules.streak(days: ["2024-02-28", "2024-02-29", "2024-03-01"], now: now, timeZone: zone) == 3)
        #expect(LearningRules.streak(days: ["2024-02-28"], now: now, timeZone: zone) == 0)
    }

    @Test(arguments: [(8, 10, true), (7, 10, false), (0, 0, false), (11, 10, false), (-1, 10, false), (4, 5, true)])
    func passingBoundary(correct: Int, total: Int, expected: Bool) {
        #expect(LearningRules.isPassing(correct: correct, total: total) == expected)
    }
}
