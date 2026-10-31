import Foundation

enum ReleaseConfiguration {
    private struct Publisher: Decodable { let displayName: String; let supportEmail: String; let privacyPolicyURL: String }
    private static let publisher: Publisher? = {
        guard let url = Bundle.main.url(forResource: "Publisher", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Publisher.self, from: data)
    }()
    static var displayName: String { publisher?.displayName ?? "" }
    static var supportEmail: String { publisher?.supportEmail ?? "" }
    static var privacyPolicyURL: String { publisher?.privacyPolicyURL ?? "" }
    static var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "") (\(info["CFBundleVersion"] as? String ?? ""))"
    }
    static var policyURL: URL? {
        guard let url = URL(string: privacyPolicyURL), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil else { return nil }
        return url
    }
}
