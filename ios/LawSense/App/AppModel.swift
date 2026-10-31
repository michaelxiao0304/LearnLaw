import Foundation
import Observation

@MainActor @Observable final class AppModel {
    private let makeUserStore: @MainActor () throws -> UserStore

    init(makeUserStore: @escaping @MainActor () throws -> UserStore = AppModel.openUserStore) {
        self.makeUserStore = makeUserStore
    }

    private static func openUserStore() throws -> UserStore {
        #if DEVELOPMENT_CONTENT
        let inMemory = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        let inMemory = false
        #endif
        return try UserStore(container: UserStore.makeContainer(inMemory: inMemory))
    }

    private(set) var searchIndex: ContentSearch?
    private(set) var catalog: ContentCatalog?
    private(set) var user: UserStore?
    private(set) var loading = false
    var loadError: String?
    var userStorageError: String?
    var actionError: String?
    var todayQuestion: Question?
    var todayKey = ""

    func load() async {
        guard !loading else { return }
        loading = true; loadError = nil
        defer { loading = false }
        do {
            let contents = try await ContentLoader.load()
            searchIndex = await Self.index(contents)
            catalog = contents
            do {
                user = try makeUserStore()
                userStorageError = nil
            } catch {
                userStorageError = error.localizedDescription
                user = UserStore(readOnly: true)
            }
            refreshDay()
        } catch is CancellationError { }
        catch { loadError = error.localizedDescription }
    }

    @concurrent private static func index(_ catalog: ContentCatalog) async -> ContentSearch { ContentSearch(catalog: catalog) }

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
    var reminderEnabled: Bool { didSet { defaults.set(reminderEnabled, forKey: "reminderEnabled") } }
    var reminderHour: Int { didSet { defaults.set(reminderHour, forKey: "reminderHour") } }
    var reminderMinute: Int { didSet { defaults.set(reminderMinute, forKey: "reminderMinute") } }
    var reminderSettings: ReminderSettings { .init(enabled: reminderEnabled, hour: reminderHour, minute: reminderMinute) }
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
        reminderEnabled = defaults.bool(forKey: "reminderEnabled")
        reminderHour = min(23, max(0, defaults.object(forKey: "reminderHour") as? Int ?? 9))
        reminderMinute = min(59, max(0, defaults.integer(forKey: "reminderMinute")))
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
