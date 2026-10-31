import Foundation

enum LearningRank: String, Codable, CaseIterable, Sendable {
    case bronze, silver, gold, master
    var title: String {
        switch self { case .bronze: "青铜"; case .silver: "白银"; case .gold: "黄金"; case .master: "王者" }
    }
}
struct CourseLevel: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let rank: LearningRank
    let prerequisiteIDs: [String]
    let questionIDs: [String]
}
struct CoursePlan: Codable, Sendable {
    let id: String
    let levels: [CourseLevel]
    func validate(questionIDs: Set<String>, minimumQuestions: Int = 10) throws {
        let ids = Set(levels.map(\.id))
        guard !id.isEmpty, !levels.isEmpty, levels.count <= 1000, ids.count == levels.count,
              minimumQuestions > 0 else { throw ContentError.invalid("课程身份或关卡数量无效") }
        for rank in LearningRank.allCases {
            guard levels.contains(where: { $0.rank == rank }) else { throw ContentError.invalid("课程缺少称号阶段") }
        }
        for level in levels {
            guard !level.id.isEmpty, level.questionIDs.count >= minimumQuestions,
                  Set(level.questionIDs).count == level.questionIDs.count,
                  Set(level.questionIDs).isSubset(of: questionIDs),
                  Set(level.prerequisiteIDs).isSubset(of: ids) else { throw ContentError.invalid("关卡 \(level.id) 缺题、重复或先修引用无效") }
        }
        var checked: Set<String> = []
        while checked.count < levels.count {
            let ready = levels.filter { !checked.contains($0.id) && Set($0.prerequisiteIDs).isSubset(of: checked) }
            guard !ready.isEmpty else { throw ContentError.invalid("课程先修关系存在循环") }
            checked.formUnion(ready.map(\.id))
        }
    }
    func isUnlocked(_ level: CourseLevel, passed: Set<String>) -> Bool { Set(level.prerequisiteIDs).isSubset(of: passed) }
    func rank(passed: Set<String>) -> LearningRank? {
        var result: LearningRank?
        for rank in LearningRank.allCases {
            let required = levels.filter { $0.rank == rank }
            guard !required.isEmpty, required.allSatisfy({ passed.contains($0.id) }) else { break }
            result = rank
        }
        return result
    }
}
struct QuestionVersion: Codable, Equatable, Sendable {
    let id: String
    let revision: Int
}
struct CourseSession: Codable, Sendable {
    let id: String
    let planID: String
    let levelID: String
    let questions: [QuestionVersion]
    var position: Int
    var selected: String?
    var finished: Bool { position == questions.count }
    var key: String { Self.key(planID: planID, levelID: levelID) }
    func attemptID(at position: Int) -> String { "course:\(id):\(position)" }
    static func key(planID: String, levelID: String) -> String { [planID, levelID].map { "\($0.utf8.count):\($0)" }.joined() }
}
