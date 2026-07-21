import Foundation

enum ScreenTimeAuthStatus: String, Sendable {
    case notDetermined
    case approved
    case denied
}

/// The one voice for selection summaries: zero components drop out, singulars
/// read correctly, and an empty selection says so plainly (D12).
enum SelectionSummaryText {
    /// "14 apps · 2 categories" / "2 categories" / "1 app" / "nothing yet"
    static func line(apps: Int, categories: Int) -> String {
        var parts: [String] = []
        if apps > 0 {
            parts.append("\(apps) app\(apps == 1 ? "" : "s")")
        }
        if categories > 0 {
            parts.append("\(categories) categor\(categories == 1 ? "y" : "ies")")
        }
        guard !parts.isEmpty else { return "nothing yet" }
        return parts.joined(separator: " \u{00B7} ")
    }
}

enum ScreenTimeError: Error, Equatable, Sendable {
    case monitoringFailed(String)
}

/// The seam that keeps every screen simulator-drivable: Live wraps
/// FamilyControls/ManagedSettings/DeviceActivity on device; Mock simulates the
/// whole lifecycle in-process. UI and SessionCoordinator only ever see this.
@MainActor
protocol ScreenTimeService: AnyObject {
    var isMock: Bool { get }
    var authorizationStatus: ScreenTimeAuthStatus { get }

    func refreshAuthorizationStatus()
    func requestAuthorization() async -> ScreenTimeAuthStatus

    /// Apply shields for an encoded FamilyActivitySelection under a named store.
    func applyShields(selectionData: Data?, activityName: String)
    func clearShields(activityName: String)

    /// One-shot DeviceActivity interval whose only job is intervalDidEnd —
    /// the janitor that clears a manual session when the app is dead.
    func startEndTimer(activityName: String, from start: Date, to end: Date) throws
    func stopActivities(_ names: [String])

    /// Repeating weekday interval; shields applied by the monitor extension at
    /// intervalDidStart.
    func registerSchedule(_ interval: RegisteredInterval) throws
    func unregisterSchedules(activityNames: [String])

    /// Human-readable summary of an encoded selection (apps, categories).
    func selectionSummary(from data: Data?) -> (apps: Int, categories: Int)
}

@MainActor
enum ScreenTimeServiceFactory {
    /// Simulator and UI-test runs always get the mock — FamilyControls can
    /// neither authorize nor shield there.
    static func make() -> any ScreenTimeService {
        #if targetEnvironment(simulator)
        return MockScreenTimeService()
        #else
        if ProcessInfo.processInfo.arguments.contains("-UITestMode") {
            return MockScreenTimeService()
        }
        return LiveScreenTimeService()
        #endif
    }
}
