import Foundation
import Observation
import UserNotifications

enum ReminderAuthorization { case unknown, allowed, denied }

struct ReminderSettings: Equatable, Sendable {
    let enabled: Bool
    let hour: Int
    let minute: Int
    var valid: Bool { (0...23).contains(hour) && (0...59).contains(minute) }
}

@MainActor protocol ReminderClient {
    func authorization() async -> ReminderAuthorization
    func requestAuthorization() async throws -> Bool
    func schedule(hour: Int, minute: Int) async throws
    func cancel()
}

@MainActor @Observable final class ReminderService {
    private let client: any ReminderClient
    private var tail: Task<Void, Never>?
    private var generation = 0
    private var permissionRequested = false
    private(set) var authorization: ReminderAuthorization = .unknown
    private(set) var error: String?

    init(client: any ReminderClient = SystemReminderClient()) { self.client = client }

    func synchronize(_ settings: ReminderSettings, requestPermission: Bool = false) async {
        if !settings.enabled { permissionRequested = false }
        else if requestPermission { permissionRequested = true }
        generation += 1
        let current = generation
        let previous = tail
        let task = Task { [weak self] in
            await previous?.value
            guard let self, current == self.generation else { return }
            await self.apply(settings, generation: current)
        }
        tail = task
        await task.value
    }

    private func apply(_ settings: ReminderSettings, generation current: Int) async {
        error = nil
        do {
            authorization = await client.authorization()
            guard current == generation else { return }
            let shouldRequest = permissionRequested
            permissionRequested = false
            guard settings.enabled else { client.cancel(); return }
            guard settings.valid else { client.cancel(); error = "提醒时间无效，请重新选择。"; return }
            if authorization == .unknown && shouldRequest {
                authorization = try await client.requestAuthorization() ? .allowed : .denied
            }
            guard current == generation else { return }
            guard authorization == .allowed else { client.cancel(); return }
            try await client.schedule(hour: settings.hour, minute: settings.minute)
        } catch {
            client.cancel()
            self.error = "提醒尚未设置，请重试。\(error.localizedDescription)"
        }
    }
}

@MainActor final class SystemReminderClient: ReminderClient {
    nonisolated static let identifier = "lawsense.daily-reminder"
    private let center = UNUserNotificationCenter.current()
    func authorization() async -> ReminderAuthorization {
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral: return .allowed
        case .denied: return .denied
        default: return .unknown
        }
    }
    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }
    func schedule(hour: Int, minute: Int) async throws {
        let content = UNMutableNotificationContent()
        content.title = "识法 · 今日一题"
        content.body = "来答今日一题，积累一点法律常识。"
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
        try await center.add(UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger))
    }
    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }
}

@MainActor @Observable final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    var openDaily = false
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.notification.request.identifier == SystemReminderClient.identifier,
              response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        await MainActor.run { self.openDaily = true }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
