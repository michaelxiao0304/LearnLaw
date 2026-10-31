import Foundation
import CryptoKit

enum LearningRules {
    static func questionID(day: String, ids: [String]) -> String? {
        let ordered = Array(Set(ids)).sorted()
        guard !ordered.isEmpty else { return nil }
        // SHA-256 v1; stable across processes, devices and Swift releases.
        let digest = SHA256.hash(data: Data("daily-v1:\(day)".utf8))
        let offset = digest.reduce(0) { ($0 * 256 + Int($1)) % ordered.count }
        return ordered[offset]
    }

    static func dayKey(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func streak(days: Set<String>, now: Date, timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(dayKey(cursor, timeZone: timeZone)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while days.contains(dayKey(cursor, timeZone: timeZone)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    static func isPassing(correct: Int, total: Int) -> Bool {
        guard total > 0, correct >= 0, correct <= total else { return false }
        // ceil(total * 4 / 5), without overflow from multiplication.
        let threshold = (total / 5) * 4 + ((total % 5) * 4 + 4) / 5
        return correct >= threshold
    }
}
