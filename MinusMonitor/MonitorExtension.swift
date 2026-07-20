import DeviceActivity
import ManagedSettings

// System-spawned janitor: applies schedule shields at interval start and clears
// session/schedule shields at interval end even when the app process is dead.
// Wired for real in Phase 2d; this stub only proves the target graph.
final class MonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        ManagedSettingsStore(named: .init(activity.rawValue)).clearAllSettings()
    }
}
