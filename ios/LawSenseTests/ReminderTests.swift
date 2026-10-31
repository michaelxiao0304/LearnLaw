import Testing
@testable import LawSenseDev

@MainActor struct ReminderTests {
    @MainActor final class Client: ReminderClient {
        var permission = ReminderAuthorization.unknown
        var grants = false
        var requests = 0
        var scheduled: (Int, Int)?
        var fails = false
        var delay = false
        var started = false
        var authorizationDelay = false
        var authorizationStarted = false
        func authorization() async -> ReminderAuthorization {
            authorizationStarted = true
            if authorizationDelay { try? await Task.sleep(for: .milliseconds(50)) }
            return permission
        }
        func requestAuthorization() async throws -> Bool { requests += 1; return grants }
        func schedule(hour: Int, minute: Int) async throws {
            started = true
            if delay { try await Task.sleep(for: .milliseconds(50)) }
            if fails { throw ContentError.invalid("test failure") }
            scheduled = (hour, minute)
        }
        func cancel() { scheduled = nil }
    }
    @Test func disabledAndBackgroundRefreshNeverPrompt() async {
        let client = Client(); let service = ReminderService(client: client)
        await service.synchronize(.init(enabled: false, hour: 9, minute: 0))
        await service.synchronize(.init(enabled: true, hour: 9, minute: 0))
        #expect(client.requests == 0 && client.scheduled == nil)
    }
    @Test func turningOffBeforeAuthorizationReturnsDoesNotPrompt() async {
        let client = Client(); client.authorizationDelay = true
        let service = ReminderService(client: client)
        let enabling = Task { await service.synchronize(.init(enabled: true, hour: 9, minute: 0), requestPermission: true) }
        for _ in 0..<100 where !client.authorizationStarted { await Task.yield() }
        #expect(client.authorizationStarted)
        await service.synchronize(.init(enabled: false, hour: 9, minute: 0))
        await enabling.value
        #expect(client.requests == 0)
    }
    @Test func disablingDuringAnInFlightScheduleLeavesNoReminder() async throws {
        let client = Client(); client.permission = .allowed; client.delay = true
        let service = ReminderService(client: client)
        let enabling = Task { await service.synchronize(.init(enabled: true, hour: 9, minute: 0)) }
        for _ in 0..<100 where !client.started { await Task.yield() }
        #expect(client.started)
        await service.synchronize(.init(enabled: false, hour: 9, minute: 0))
        await enabling.value
        #expect(client.scheduled == nil)
    }
    @Test func denialRevocationTimeChangesAndFailureAreRecoverable() async {
        let client = Client(); let service = ReminderService(client: client)
        await service.synchronize(.init(enabled: true, hour: 9, minute: 0), requestPermission: true)
        #expect(client.requests == 1 && client.scheduled == nil)
        client.permission = .allowed
        await service.synchronize(.init(enabled: true, hour: 10, minute: 30))
        #expect(client.scheduled?.0 == 10 && client.scheduled?.1 == 30)
        client.permission = .denied
        await service.synchronize(.init(enabled: true, hour: 10, minute: 30))
        #expect(client.scheduled == nil)
        client.permission = .allowed; client.fails = true
        await service.synchronize(.init(enabled: true, hour: 10, minute: 30))
        #expect(service.error != nil && client.scheduled == nil)
        client.fails = false
        await service.synchronize(.init(enabled: true, hour: 10, minute: 30))
        #expect(service.error == nil && client.scheduled != nil)
        await service.synchronize(.init(enabled: false, hour: 10, minute: 30))
        #expect(client.scheduled == nil)
    }
}
