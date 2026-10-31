import Foundation
import Observation

@MainActor @Observable final class AppModel {
    private(set) var catalog: ContentCatalog?
    private(set) var user: UserStore?
    private(set) var loading = false
    var loadError: String?
    var actionError: String?
    var todayQuestion: Question?
    var todayKey = ""

    func load() async {
        guard !loading else { return }
        loading = true; loadError = nil
        defer { loading = false }
        do {
            let contents = try await ContentLoader.load()
            catalog = contents
            #if DEVELOPMENT_CONTENT
            let inMemory = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            #else
            let inMemory = false
            #endif
            user = try UserStore(container: UserStore.makeContainer(inMemory: inMemory))
            refreshDay()
        } catch is CancellationError { }
        catch { loadError = error.localizedDescription }
    }

    func perform(_ action: () throws -> Void) {
        do { try action() } catch { actionError = "操作尚未完成：\(error.localizedDescription)" }
    }

    func refreshDay() {
        todayKey = LearningRules.dayKey(.now, timeZone: .current)
        guard let catalog, let user else { return }
        perform { todayQuestion = try user.daily(catalog: catalog) }
    }
}

@MainActor @Observable final class Preferences {
    static let disclaimerVersion = "2026-10-v1"
    private let defaults: UserDefaults
    var acknowledged: Bool
    var largerText: Bool { didSet { defaults.set(largerText, forKey: "largerText") } }
    var speechRate: Double { didSet { defaults.set(speechRate, forKey: "speechRate") } }

    init() {
        #if DEVELOPMENT_CONTENT
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"), let isolated = UserDefaults(suiteName: "LawSenseUITests") {
            defaults = isolated
            defaults.removePersistentDomain(forName: "LawSenseUITests")
        } else { defaults = .standard }
        #else
        defaults = .standard
        #endif
        acknowledged = defaults.string(forKey: "acknowledgedVersion") == Self.disclaimerVersion
        largerText = defaults.bool(forKey: "largerText")
        speechRate = defaults.object(forKey: "speechRate") as? Double ?? 0.45
    }
    func acknowledge() {
        defaults.set(Self.disclaimerVersion, forKey: "acknowledgedVersion")
        defaults.set(Date.now, forKey: "acknowledgedAt")
        acknowledged = true
    }
}
