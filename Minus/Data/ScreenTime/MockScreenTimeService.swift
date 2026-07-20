import Foundation

extension Notification.Name {
    /// Posted by the mock when a simulated interval ends while the app runs,
    /// so SessionCoordinator reconciles immediately (on device the real signal
    /// is the monitor extension's pending-event ledger).
    static let minusMockIntervalEnded = Notification.Name("minusMockIntervalEnded")
}

/// Full in-memory simulation of the Screen Time lifecycle: authorization with
/// a visible in-flight state, named "shields", one-shot end timers that fire
/// the same pending-event ledger the real extension writes, and a fake
/// selection format for the blocked-apps picker.
@MainActor
@Observable
final class MockScreenTimeService: ScreenTimeService {
    var isMock: Bool { true }
    private(set) var authorizationStatus: ScreenTimeAuthStatus = .notDetermined

    /// Named stores currently "shielded" — inspectable by tests and the gallery.
    private(set) var shieldedActivities: Set<String> = []
    private var endTimers: [String: Task<Void, Never>] = [:]

    /// MINUS_STATE=denied forces the denial path for stories ON-4/SE-6.
    private var forceDenied: Bool {
        ProcessInfo.processInfo.environment["MINUS_STATE"] == "denied"
    }

    init() {
        if ProcessInfo.processInfo.environment["MINUS_STATE"] != nil,
           ProcessInfo.processInfo.environment["MINUS_STATE"] != "fresh" {
            authorizationStatus = forceDenied ? .denied : .approved
        }
    }

    func refreshAuthorizationStatus() {}

    func requestAuthorization() async -> ScreenTimeAuthStatus {
        // Brief delay so the "requesting" UI state is real and screenshot-able.
        try? await Task.sleep(for: .milliseconds(500))
        authorizationStatus = forceDenied ? .denied : .approved
        return authorizationStatus
    }

    func applyShields(selectionData: Data?, activityName: String) {
        shieldedActivities.insert(activityName)
    }

    func clearShields(activityName: String) {
        shieldedActivities.remove(activityName)
    }

    func startEndTimer(activityName: String, from start: Date, to end: Date) throws {
        endTimers[activityName]?.cancel()
        let interval = end.timeIntervalSince(ClockProvider.now())
        guard interval > 0 else { throw ScreenTimeError.monitoringFailed("interval already over") }
        endTimers[activityName] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            // Mirror exactly what MonitorExtension.intervalDidEnd does.
            SharedState.appendPendingEvent(MonitorEvent(kind: .intervalEnded, activityName: activityName, date: Date()))
            self?.clearShields(activityName: activityName)
            NotificationCenter.default.post(name: .minusMockIntervalEnded, object: nil)
        }
    }

    func stopActivities(_ names: [String]) {
        for name in names {
            endTimers[name]?.cancel()
            endTimers[name] = nil
        }
    }

    func registerSchedule(_ interval: RegisteredInterval) throws {
        // Registry bookkeeping is the coordinator's job; nothing to do here.
    }

    func unregisterSchedules(activityNames: [String]) {}

    // MARK: Mock selection format

    /// The simulator can't show FamilyActivityPicker, so BlockedStep writes
    /// this instead: {"mockApps": n, "mockCategories": m}.
    struct MockSelection: Codable, Sendable {
        var mockApps: Int
        var mockCategories: Int
    }

    static func encodeSelection(apps: Int, categories: Int) -> Data {
        (try? JSONEncoder().encode(MockSelection(mockApps: apps, mockCategories: categories))) ?? Data()
    }

    func selectionSummary(from data: Data?) -> (apps: Int, categories: Int) {
        guard let data,
              let selection = try? JSONDecoder().decode(MockSelection.self, from: data) else {
            return (0, 0)
        }
        return (selection.mockApps, selection.mockCategories)
    }
}
