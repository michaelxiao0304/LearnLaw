import Foundation
import Testing
@testable import LawSenseCore

struct SharingTests {
    @Test func paginatedOriginalIsNeverDroppedOrRewritten() {
        let original = String(repeating: "原文。👨‍👩‍👧‍👦\n", count: 80)
        let pages = SharePagination.pages(text: original, limit: 30)
        #expect(pages.count > 1)
        #expect(pages.allSatisfy { $0.count <= 30 })
        #expect(pages.joined() == original)
    }
    @Test func correctionIncludesVersionAndNeverCreatesUnconfiguredRecipient() throws {
        let draft = FeedbackDraft(contentID: "card:1", packageID: "bundle-v2", version: "0.1 (1)", explanation: "引文 & 标点?\n请核查")
        #expect(draft.body.contains("bundle-v2") && draft.body.contains("card:1"))
        #expect(draft.emailURL(recipient: "") == nil)
        #expect(draft.emailURL(recipient: "bad\n@example.com") == nil)
        let url = try #require(draft.emailURL(recipient: "editor@example.com"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.first { $0.name == "body" }?.value == draft.body)
    }
}
