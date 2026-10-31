import Foundation

/// Immutable in-memory index built once away from the UI actor.
struct ContentSearch: Sendable {
    let catalog: ContentCatalog
    private let fields: [[String]]
    private let postings: [String: Set<Int>]
    private let aliases: [(name: String, law: String)]

    init(catalog: ContentCatalog) {
        self.catalog = catalog
        let titles = Dictionary(uniqueKeysWithValues: catalog.laws.map { ($0.id, $0.title) })
        fields = catalog.articles.map { article in
            [article.title, article.text, titles[article.reference.lawId] ?? ""].map(Self.normalize)
        }
        var index: [String: Set<Int>] = [:]
        for (position, values) in fields.enumerated() {
            for token in Set(values.flatMap(Self.tokens)) { index[token, default: []].insert(position) }
        }
        postings = index
        let names: [String: [String]] = [
            "criminal": ["刑法", "中华人民共和国刑法", "xingfa", "xf"],
            "civil": ["民法典", "中华人民共和国民法典", "民法", "minfadian", "mfd"],
            "public_security": ["治安管理处罚法", "中华人民共和国治安管理处罚法", "治安法", "zhian", "zaglcff"]
        ]
        var entries: [(name: String, law: String)] = []
        for law in catalog.laws {
            let variants = Set([law.title] + (names[law.id] ?? []))
            for name in variants { entries.append((Self.normalize(name), law.id)) }
        }
        aliases = entries.sorted { left, right in
            if left.name.count == right.name.count { return left.name < right.name }
            return left.name.count > right.name.count
        }
    }

    func articles(query: String, lawId: String? = nil) -> [Article] {
        guard query.count <= 100 else { return [] }
        var needle = Self.normalize(query)
        var selectedLaw = lawId
        if let alias = aliases.first(where: { needle.hasPrefix($0.name) }) {
            let remainder = String(needle.dropFirst(alias.name.count)).trimmingCharacters(in: .whitespaces)
            if remainder.isEmpty || Self.articleNumber(remainder) != nil {
                if let lawId, lawId != alias.law { return [] }
                selectedLaw = alias.law; needle = remainder
            }
        }
        let number = Self.articleNumber(needle)
        var candidates: Set<Int>?
        if !needle.isEmpty && number == nil {
            let characters = Array(needle)
            let terms = characters.count == 1 ? [needle] : zip(characters, characters.dropFirst()).map { String([$0, $1]) }
            for token in terms {
                guard let matches = postings[token] else { return [] }
                candidates = candidates.map { $0.intersection(matches) } ?? matches
                if candidates?.isEmpty == true { return [] }
            }
        }
        return catalog.articles.enumerated().compactMap { index, article in
            guard selectedLaw == nil || article.reference.lawId == selectedLaw else { return nil }
            if let number { return article.reference.articleKey == number ? article : nil }
            if needle.isEmpty { return article }
            guard candidates?.contains(index) == true, fields[index].contains(where: { $0.contains(needle) }) else { return nil }
            return article
        }
    }

    func suggestions(for query: String) -> [String] {
        let value = Self.normalize(query)
        guard !value.isEmpty else { return [] }
        let ids = Set(aliases.filter { $0.name.hasPrefix(value) }.map(\.law))
        return catalog.laws.filter { ids.contains($0.id) }.map(\.title)
    }

    private static func tokens(_ text: String) -> [String] {
        let characters = Array(text)
        return characters.map(String.init) + zip(characters, characters.dropFirst()).map { String([$0, $1]) }
    }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.widthInsensitive, .caseInsensitive], locale: Locale(identifier: "zh_CN"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func articleNumber(_ query: String) -> String? {
        let query = normalize(query)
        guard query.range(of: "^第?[0-9一二三四五六七八九十百千零〇]+条?(之[0-9一二三四五六七八九十百千零〇]+)?$", options: .regularExpression) != nil else { return nil }
        let value = query.replacingOccurrences(of: "第", with: "").replacingOccurrences(of: "条", with: "")
        let parts = value.components(separatedBy: "之")
        let numbers = parts.compactMap(parseNumber)
        guard numbers.count == parts.count else { return nil }
        return numbers.map(String.init).joined(separator: "-")
    }

    private static func parseNumber(_ part: String) -> Int? {
        if let number = Int(part) { return (1...99999).contains(number) ? number : nil }
        let digits: [Character: Int] = ["一":1,"二":2,"三":3,"四":4,"五":5,"六":6,"七":7,"八":8,"九":9,"零":0,"〇":0]
        let units: [Character: Int] = ["十":10,"百":100,"千":1000]
        var total = 0; var digit = 0; var lastUnit = 10000; var hasDigit = false
        for character in part {
            if let next = digits[character] {
                if hasDigit && digit != 0 { return nil }
                digit = next; hasDigit = true
            } else if let unit = units[character], unit < lastUnit {
                total += max(digit, 1) * unit; digit = 0; lastUnit = unit; hasDigit = false
            } else { return nil }
        }
        return total + digit > 0 ? total + digit : nil
    }
}
