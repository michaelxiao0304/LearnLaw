import Foundation

struct ContentSearch: Sendable {
    let catalog: ContentCatalog

    func articles(query: String, lawId: String? = nil) -> [Article] {
        let needle = Self.normalize(query)
        let filtered = catalog.articles.filter { lawId == nil || $0.reference.lawId == lawId }
        guard !needle.isEmpty else { return filtered }
        let number = Self.articleNumber(needle)
        return filtered.filter { article in
            if let number { return article.reference.articleKey == number }
            let law = catalog.laws.first { $0.id == article.reference.lawId }?.title ?? ""
            return Self.normalize(article.title + article.text + law).contains(needle)
        }
    }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.widthInsensitive, .caseInsensitive], locale: Locale(identifier: "zh_CN"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func articleNumber(_ query: String) -> String? {
        var value = query.replacingOccurrences(of: "第", with: "").replacingOccurrences(of: "条", with: "")
        let parts = value.components(separatedBy: "之")
        guard parts.count <= 2 else { return nil }
        let numbers = parts.compactMap { part -> Int? in
            if let number = Int(part), number > 0 { return number }
            let digits: [Character: Int] = ["一":1,"二":2,"三":3,"四":4,"五":5,"六":6,"七":7,"八":8,"九":9,"零":0,"〇":0]
            let units: [Character: Int] = ["十":10,"百":100,"千":1000]
            var total = 0; var digit = 0
            for character in part {
                if let d = digits[character] { digit = d }
                else if let unit = units[character] { total += max(digit, 1) * unit; digit = 0 }
                else { return nil }
            }
            return total + digit > 0 ? total + digit : nil
        }
        guard numbers.count == parts.count else { return nil }
        value = numbers.map(String.init).joined(separator: "-")
        return value
    }
}
