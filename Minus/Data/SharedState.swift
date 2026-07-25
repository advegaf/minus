import Foundation

// The app↔extension contract. This file is compiled into BOTH the Minus app
// target and the MinusMonitor extension (vita's contract-file pattern). The
// extension has a single-digit-MB memory ceiling and must never open SwiftData
// — everything it needs lives in these small JSON blobs in the app group.

/// A running focus interval the monitor may need to reconcile.
struct ActivitySnapshot: Codable, Sendable, Identifiable {
    var id: UUID { sessionID }
    var activityName: String
    var sessionID: UUID
    var startedAt: Date
    var plannedEndAt: Date
}

/// A registered schedule interval, keyed by DeviceActivity name, carrying the
/// encoded FamilyActivitySelection the extension applies at interval start.
struct RegisteredInterval: Codable, Sendable {
    var activityName: String
    var scheduleID: UUID
    var selectionData: Data
    var weekday: Int
    var startMinuteOfDay: Int
    var endMinuteOfDay: Int
}

enum MonitorEventKind: String, Codable, Sendable {
    case intervalStarted
    case intervalEnded
}

/// Extension→app ledger entry, drained by SessionCoordinator.reconcile() on
/// next foreground.
struct MonitorEvent: Codable, Sendable, Identifiable {
    var id = UUID()
    var kind: MonitorEventKind
    var activityName: String
    var date: Date
}

/// Namespaced accessors over the app-group defaults. All methods are cheap,
/// synchronous, and safe from any isolation domain (UserDefaults is
/// thread-safe).
enum SharedState {
    private enum Key {
        static let activeSessions = "minus.activeSessions"
        static let scheduleRegistry = "minus.scheduleRegistry"
        static let pendingEvents = "minus.pendingEvents"
    }

    /// The app-group id comes from Info.plist (`MinusAppGroup`, present in both
    /// the app and monitor plists) so no bundle id is ever hardcoded.
    static var appGroupID: String {
        Bundle.main.object(forInfoDictionaryKey: "MinusAppGroup") as? String ?? ""
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    private static func read<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func write(_ value: some Encodable, key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    // MARK: Active sessions

    static var activeSessions: [ActivitySnapshot] {
        get { read(Key.activeSessions, as: [ActivitySnapshot].self) ?? [] }
        set { write(newValue, key: Key.activeSessions) }
    }

    static func removeActiveSession(activityName: String) {
        activeSessions.removeAll { $0.activityName == activityName }
    }

    // MARK: Schedule registry

    /// Keyed by DeviceActivity name.
    static var scheduleRegistry: [String: RegisteredInterval] {
        get { read(Key.scheduleRegistry, as: [String: RegisteredInterval].self) ?? [:] }
        set { write(newValue, key: Key.scheduleRegistry) }
    }

    // MARK: Pending events (extension → app)

    static func appendPendingEvent(_ event: MonitorEvent) {
        var events = read(Key.pendingEvents, as: [MonitorEvent].self) ?? []
        events.append(event)
        write(events, key: Key.pendingEvents)
    }

    static func drainPendingEvents() -> [MonitorEvent] {
        let events = read(Key.pendingEvents, as: [MonitorEvent].self) ?? []
        defaults.removeObject(forKey: Key.pendingEvents)
        return events
    }

    /// Full wipe (Settings → reset).
    static func reset() {
        for key in [Key.activeSessions, Key.scheduleRegistry, Key.pendingEvents] {
            defaults.removeObject(forKey: key)
        }
    }
}
