import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// The real thing — only meaningful on a physical device with the
/// family-controls entitlement. Compiles everywhere; the factory never
/// instantiates it on simulator.
@MainActor
@Observable
final class LiveScreenTimeService: ScreenTimeService {
    var isMock: Bool { false }
    private(set) var authorizationStatus: ScreenTimeAuthStatus = .notDetermined

    private let center = DeviceActivityCenter()

    init() {
        refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = Self.map(AuthorizationCenter.shared.authorizationStatus)
    }

    func requestAuthorization() async -> ScreenTimeAuthStatus {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            authorizationStatus = .denied
            return authorizationStatus
        }
        refreshAuthorizationStatus()
        return authorizationStatus
    }

    private static func map(_ status: AuthorizationStatus) -> ScreenTimeAuthStatus {
        switch status {
        case .approved: .approved
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    // MARK: Shields

    func applyShields(selectionData: Data?, activityName: String) {
        guard let selection = Self.decodeSelection(selectionData) else { return }
        let store = ManagedSettingsStore(named: .init(activityName))
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    func clearShields(activityName: String) {
        ManagedSettingsStore(named: .init(activityName)).clearAllSettings()
    }

    // MARK: DeviceActivity intervals

    func startEndTimer(activityName: String, from start: Date, to end: Date) throws {
        let calendar = Calendar.current
        let units: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(units, from: start),
            intervalEnd: calendar.dateComponents(units, from: end),
            repeats: false
        )
        do {
            try center.startMonitoring(DeviceActivityName(activityName), during: schedule)
        } catch {
            throw ScreenTimeError.monitoringFailed(String(describing: error))
        }
    }

    func stopActivities(_ names: [String]) {
        center.stopMonitoring(names.map { DeviceActivityName($0) })
    }

    func registerSchedule(_ interval: RegisteredInterval) throws {
        var start = DateComponents()
        start.weekday = interval.weekday
        start.hour = interval.startMinuteOfDay / 60
        start.minute = interval.startMinuteOfDay % 60
        var end = DateComponents()
        end.weekday = interval.weekday
        end.hour = interval.endMinuteOfDay / 60
        end.minute = interval.endMinuteOfDay % 60
        let schedule = DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: true)
        do {
            try center.startMonitoring(DeviceActivityName(interval.activityName), during: schedule)
        } catch {
            throw ScreenTimeError.monitoringFailed(String(describing: error))
        }
    }

    func unregisterSchedules(activityNames: [String]) {
        stopActivities(activityNames)
    }

    // MARK: Selection

    static func decodeSelection(_ data: Data?) -> FamilyActivitySelection? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    static func encodeSelection(_ selection: FamilyActivitySelection) -> Data? {
        try? JSONEncoder().encode(selection)
    }

    func selectionSummary(from data: Data?) -> (apps: Int, categories: Int) {
        guard let selection = Self.decodeSelection(data) else { return (0, 0) }
        return (selection.applicationTokens.count, selection.categoryTokens.count)
    }
}
