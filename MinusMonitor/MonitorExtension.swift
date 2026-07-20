import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

// System-spawned janitor. Runs with a single-digit-MB memory ceiling: reads
// only SharedState's small JSON blobs (never SwiftData), creates stores
// locally per callback, logs to the app-group ring buffer for field debugging.
//
// - Schedules: intervalDidStart applies shields from the registry entry;
//   intervalDidEnd clears them.
// - Manual sessions: shields were applied in-app at start; intervalDidEnd is
//   the guarantee they come down even if the app is dead.
final class MonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let name = activity.rawValue
        SharedState.appendMonitorLog("didStart \(name) \(Date().ISO8601Format())")

        guard let interval = SharedState.scheduleRegistry[name] else { return }
        guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: interval.selectionData) else {
            SharedState.appendMonitorLog("decode-failed \(name)")
            return
        }
        let store = ManagedSettingsStore(named: .init(name))
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        SharedState.appendPendingEvent(MonitorEvent(kind: .intervalStarted, activityName: name, date: Date()))
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        let name = activity.rawValue
        ManagedSettingsStore(named: .init(name)).clearAllSettings()
        SharedState.appendPendingEvent(MonitorEvent(kind: .intervalEnded, activityName: name, date: Date()))
        SharedState.appendMonitorLog("didEnd \(name) \(Date().ISO8601Format())")
    }
}
