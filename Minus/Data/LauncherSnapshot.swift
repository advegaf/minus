import Foundation

/// The tiny contract between the app and the home-screen widgets: the
/// essentials list, the intention, and where focus stands — written to the App
/// Group as JSON whenever anything changes (LauncherBridge is the only
/// writer). THIS FILE IS COMPILED INTO BOTH TARGETS (app + MinusWidget) and
/// stays deliberately self-contained: no SharedState, no SwiftData, no
/// ClockProvider (@MainActor) — widgets render from `entry.date`.
struct LauncherSnapshot: Codable, Equatable, Sendable {
    struct Essential: Codable, Equatable, Sendable, Identifiable {
        var slug: String
        var name: String
        /// Catalog urlString — informational; the bounce resolves via slug.
        var url: String
        /// canOpenURL at publish time; nil = unknown (pre-1.1 snapshots).
        var installed: Bool?

        var id: String { slug }
    }

    struct FocusState: Codable, Equatable, Sendable {
        /// A running session's planned end (manual or scheduled).
        var activeUntil: Date?
        /// FocusStateLine voice: "next · deep work · mon 9:00".
        var nextSchedule: String?
    }

    var essentials: [Essential]
    var intention: String
    var focus: FocusState
    var generatedAt: Date

    // MARK: App Group plumbing (vita WidgetSnapshot pattern)

    /// Both targets carry the MinusAppGroup Info.plist key.
    static var appGroupID: String {
        Bundle.main.object(forInfoDictionaryKey: "MinusAppGroup") as? String ?? ""
    }

    static func fileURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("launcher-snapshot.json")
    }

    func write() {
        guard let url = Self.fileURL() else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? (try? encoder.encode(self))?.write(to: url, options: .atomic)
    }

    static func read() -> LauncherSnapshot? {
        guard let url = fileURL(), let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(LauncherSnapshot.self, from: data)
    }

    static func delete() {
        guard let url = fileURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Widget-gallery placeholder fixture (never written to disk).
    static var fixture: LauncherSnapshot {
        LauncherSnapshot(
            essentials: [
                Essential(slug: "phone", name: "phone", url: "tel:", installed: true),
                Essential(slug: "messages", name: "messages", url: "sms:", installed: true),
                Essential(slug: "maps", name: "maps", url: "maps:", installed: true),
                Essential(slug: "music", name: "music", url: "music:", installed: true),
                Essential(slug: "photos", name: "photos", url: "photos-redirect:", installed: true),
            ],
            intention: "less phone. more life.",
            focus: FocusState(activeUntil: nil, nextSchedule: nil),
            generatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
