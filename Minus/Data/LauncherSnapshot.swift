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
        /// Catalog urlString. Informational: the launch order comes from the
        /// resolved `target` below.
        var url: String
        /// v1.9: the URL this cell should try FIRST, already resolved by the
        /// bridge. https means the widget can open it with zero hops; any
        /// other scheme means the cell must bounce through minus, because
        /// App Intents cannot open custom schemes. nil = pre-1.9 file.
        var target: String?
        /// Vestigial since v1.8: always nil. Kept so a stale file written by
        /// an older build still decodes.
        var installed: Bool?
        /// v1.11: the app's identity. A widget cell holding one asks
        /// LaunchServices to open it directly, so nothing bounces through
        /// minus. nil for custom entries and pre-1.11 files.
        var bundleID: String?

        var id: String { slug }
    }

    struct FocusState: Codable, Equatable, Sendable {
        /// A running session's planned end (manual or scheduled).
        var activeUntil: Date?
        /// FocusStateLine voice: "next · deep work · mon 9:00".
        var nextSchedule: String?
    }

    /// v1.6: one launcher page. Each placed widget picks a card in Edit
    /// Widget (CardQuery reads these); Home renders the first.
    struct Card: Codable, Equatable, Sendable, Identifiable {
        var id: UUID
        var name: String
        var essentials: [Essential]
    }

    /// Top-level list stays = card 1 (a v1.5 widget reading a v1.6 file, and
    /// a v1.6 widget reading a stale v1.5 file, both keep working).
    var essentials: [Essential]
    var intention: String
    var focus: FocusState
    var generatedAt: Date
    /// nil = pre-1.6 file → resolvedCards synthesizes the implicit card.
    /// Explicit nil default keeps the memberwise init v1.5-source-compatible.
    var cards: [Card]? = nil

    /// The id resolvedCards gives a v1 file's implicit card — stable, so a
    /// widget configured against it stays valid across rewrites.
    static let implicitCardID = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!

    var resolvedCards: [Card] {
        if let cards, !cards.isEmpty { return cards }
        return [Card(id: Self.implicitCardID, name: "one", essentials: essentials)]
    }

    /// Per-instance lookup with the safety net: a deleted card's widget falls
    /// back to card 1 rather than rendering nothing.
    func card(id: UUID?) -> Card? {
        let resolved = resolvedCards
        guard let id else { return resolved.first }
        return resolved.first { $0.id == id } ?? resolved.first
    }

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
        try? encoder.encode(self).write(to: url, options: .atomic)
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

    /// Widget-gallery placeholder fixture (never written to disk). Also the
    /// pre-first-launch floor for CardQuery: placeholder previews in the
    /// widget gallery resolve through this before minus ever publishes.
    static var fixture: LauncherSnapshot {
        let essentials = [
            Essential(slug: "phone", name: "phone", url: "tel:", target: nil, installed: nil),
            Essential(slug: "messages", name: "messages", url: "messages:", target: nil, installed: nil),
            Essential(slug: "maps", name: "maps", url: "maps:", target: nil, installed: nil),
            Essential(slug: "music", name: "music", url: "music:", target: nil, installed: nil),
            Essential(slug: "photos", name: "photos", url: "photos-redirect:", target: nil, installed: nil),
        ]
        return LauncherSnapshot(
            essentials: essentials,
            intention: "less phone. more life.",
            focus: FocusState(activeUntil: nil, nextSchedule: nil),
            generatedAt: Date(timeIntervalSince1970: 0),
            cards: [Card(id: implicitCardID, name: "one", essentials: essentials)]
        )
    }

    /// Full-cap fixture: the density-audit worst case (7 rows) for gallery
    /// proof frames.
    static var fixtureSeven: LauncherSnapshot {
        var snapshot = fixture
        let extra = [
            Essential(slug: "notes", name: "notes", url: "mobilenotes:", target: nil, installed: nil),
            Essential(slug: "calendar", name: "calendar", url: "calshow:", target: nil, installed: nil),
        ]
        snapshot.essentials += extra
        snapshot.cards = [Card(id: implicitCardID, name: "one", essentials: snapshot.essentials)]
        return snapshot
    }
}
