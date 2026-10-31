import Foundation

/// Intentionally unconfigured until the publisher supplies real contact details.
enum ReleaseConfiguration {
    static let supportEmail = ""
    static let privacyPolicyURL = ""
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
