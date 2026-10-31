import Testing
@testable import LawSenseCore

struct CourseTests {
    func plan(cycle: Bool = false, short: Bool = false) -> CoursePlan {
        CoursePlan(id: "plan", levels: LearningRank.allCases.enumerated().map { index, rank in
            CourseLevel(id: rank.rawValue, title: rank.title, rank: rank,
                prerequisiteIDs: index == 0 ? (cycle ? ["master"] : []) : [LearningRank.allCases[index - 1].rawValue],
                questionIDs: (1...(short ? 2 : 10)).map { "q\($0)" })
        })
    }
    @Test func invalidPlansCannotUnlockRanks() {
        #expect(throws: ContentError.self) { try plan(cycle: true).validate(questionIDs: Set((1...10).map { "q\($0)" })) }
        #expect(throws: ContentError.self) { try plan(short: true).validate(questionIDs: Set((1...10).map { "q\($0)" })) }
        #expect(throws: ContentError.self) { try plan().validate(questionIDs: ["q1"]) }
    }
    @Test func rankRequiresEveryEarlierStageAndPrerequisites() throws {
        let plan = plan()
        try plan.validate(questionIDs: Set((1...10).map { "q\($0)" }))
        #expect(plan.rank(passed: ["bronze", "silver"]) == .silver)
        #expect(plan.rank(passed: ["master"]) == nil)
        #expect(!plan.isUnlocked(plan.levels[1], passed: []))
        #expect(plan.isUnlocked(plan.levels[1], passed: ["bronze"]))
    }
}
