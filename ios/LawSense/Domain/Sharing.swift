import Foundation

struct FeedbackDraft: Sendable {
    let contentID: String
    let packageID: String
    let version: String
    let explanation: String
    var body: String {
        "内容纠错（仅用于内容反馈，不提供法律咨询）\n内容 ID：\(contentID)\n内容包：\(packageID)\nApp 版本：\(version)\n\n说明：\n\(explanation)"
    }
    func emailURL(recipient: String) -> URL? {
        guard recipient.range(of: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$", options: .regularExpression) != nil else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"; components.path = recipient
        components.queryItems = [URLQueryItem(name: "subject", value: "识法内容纠错 · \(contentID)"), URLQueryItem(name: "body", value: body)]
        return components.url
    }
}

enum SharePagination {
    /// Chunk only at extended grapheme boundaries; concatenating pages returns the exact original.
    static func pages(text: String, limit: Int = 300) -> [String] {
        guard !text.isEmpty else { return [] }
        let size = max(1, limit)
        var page = ""
        var count = 0
        var lineBreaks = 0
        var pages: [String] = []
        for character in text {
            if count == size || lineBreaks == 8 {
                pages.append(page); page = ""; count = 0; lineBreaks = 0
            }
            page.append(character); count += 1
            if character.isNewline { lineBreaks += 1 }
        }
        if !page.isEmpty { pages.append(page) }
        return pages
    }
}
