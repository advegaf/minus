import Foundation
import SwiftData

// CloudKit-legal rules throughout (future-proofing, mirrors vita): every
// property defaulted or optional, no #Unique, uniqueness via fetch-before-
// insert, no required relationships.

enum Strictness: String, Codable, CaseIterable, Sendable {
    /// End-early is one tap.
    case normal
    /// End-early requires a deliberate hold.
    case friction
    /// End-early is hidden until the session completes.
    case strict
}

enum SessionSource: String, Codable, Sendable {
    case manual
    case schedule
}

enum SessionEndReason: String, Codable, Sendable {
    /// Ran its full planned interval.
    case completed
    /// User ended it through the strictness gate.
    case endedEarly
    /// Marked closed by the foreground sweep after the fact.
    case reconciled
}

/// Singleton (fetch-or-create by well-known id): the user's intention,
/// strictness, and onboarding gate.
@Model
final class UserConfig {
    var id: UUID = UserConfig.wellKnownID
    var intentionText: String = ""
    /// v1.7: the goal stays saved either way; this only governs whether it
    /// renders (Home line + widget footers).
    var showsIntention: Bool = true
    var strictnessRaw: String = Strictness.normal.rawValue
    var onboardedAt: Date?
    var createdAt: Date = Date.now

    init() {}

    static let wellKnownID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    var strictness: Strictness {
        get { Strictness(rawValue: strictnessRaw) ?? .normal }
        set { strictnessRaw = newValue.rawValue }
    }
}

/// v1.6: the custom-entry registry ONLY. Catalog apps resolve from code
/// (EssentialAppCatalog) and live as slugs inside LauncherCard.orderedSlugs;
/// a row here is a user-typed app ("custom-" slug prefix) whose launch routes
/// through its matching one-action Shortcut. Pre-1.6 catalog rows are folded
/// into the default card at bootstrap (AppDependencies.migrateToCards).
@Model
final class EssentialApp {
    var slug: String = ""
    var displayName: String = ""
    var urlScheme: String = ""
    var sortOrder: Int = 0
    var isEnabled: Bool = true

    init(slug: String, displayName: String, urlScheme: String, sortOrder: Int) {
        self.slug = slug
        self.displayName = displayName
        self.urlScheme = urlScheme
        self.sortOrder = sortOrder
    }
}

/// A named set of essentials — one launcher page. Each home-screen widget
/// instance picks a card in Edit Widget; Home renders the first (sortOrder).
@Model
final class LauncherCard {
    var id: UUID = UUID()
    var name: String = ""
    /// ≤ homeCap slugs, launcher order. Catalog slugs resolve from code;
    /// "custom-" slugs resolve from the EssentialApp registry.
    var orderedSlugs: [String] = []
    var sortOrder: Int = 0
    var createdAt: Date = Date.now

    init(name: String, orderedSlugs: [String], sortOrder: Int) {
        self.name = name
        self.orderedSlugs = orderedSlugs
        self.sortOrder = sortOrder
    }
}

/// Pure slug machinery for custom entries. "Pilates Studio" → "custom-pilates-
/// studio", launched via shortcuts://run-shortcut?name=minus-pilates-studio —
/// the guide walks the user through creating that one-action shortcut.
enum CustomSlug {
    static let prefix = "custom-"

    static func isCustom(_ slug: String) -> Bool { slug.hasPrefix(prefix) }

    /// The shortcut-name half: "custom-pilates-studio" → "pilates-studio".
    static func bare(_ slug: String) -> String {
        isCustom(slug) ? String(slug.dropFirst(prefix.count)) : slug
    }

    /// Lowercase, alphanumerics kept, runs of anything else become one hyphen;
    /// de-duped against existing slugs with -2, -3… suffixes.
    static func make(name: String, existing: Set<String>) -> String {
        let lowered = name.lowercased()
        var core = ""
        var pendingHyphen = false
        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                if pendingHyphen && !core.isEmpty { core.append("-") }
                pendingHyphen = false
                core.unicodeScalars.append(scalar)
            } else {
                pendingHyphen = true
            }
        }
        if core.isEmpty { core = "app" }
        let base = prefix + core
        if !existing.contains(base) { return base }
        var counter = 2
        while existing.contains("\(base)-\(counter)") { counter += 1 }
        return "\(base)-\(counter)"
    }
}

/// The blocked-apps selection. `selectionData` is an encoded (opaque)
/// FamilyActivitySelection; decode failures mean stale tokens after a
/// restore/reinstall and surface a re-pick recovery path in Settings.
@Model
final class BlockList {
    var id: UUID = UUID()
    var name: String = "Blocked"
    var selectionData: Data?
    var isDefault: Bool = true
    var updatedAt: Date = Date.now

    init() {}
}

/// Append-only log of focus sessions. All stats derive live from these rows —
/// no materialized stat tables.
@Model
final class FocusSession {
    var id: UUID = UUID()
    var startedAt: Date = Date.now
    var plannedEndAt: Date = Date.now
    var endedAt: Date?
    var endReasonRaw: String?
    var sourceRaw: String = SessionSource.manual.rawValue
    var activityName: String = ""
    var scheduleID: UUID?

    init(startedAt: Date, plannedEndAt: Date, source: SessionSource, activityName: String, scheduleID: UUID? = nil) {
        self.startedAt = startedAt
        self.plannedEndAt = plannedEndAt
        self.sourceRaw = source.rawValue
        self.activityName = activityName
        self.scheduleID = scheduleID
    }

    var source: SessionSource {
        SessionSource(rawValue: sourceRaw) ?? .manual
    }

    var endReason: SessionEndReason? {
        get { endReasonRaw.flatMap(SessionEndReason.init(rawValue:)) }
        set { endReasonRaw = newValue?.rawValue }
    }

    var isActive: Bool { endedAt == nil }
}

/// A recurring block window. Registration expands to one DeviceActivity name
/// per selected weekday (see ScheduleMath); v1 windows never cross midnight.
@Model
final class FocusSchedule {
    var id: UUID = UUID()
    var name: String = ""
    /// Calendar.weekday values: 1 = Sunday … 7 = Saturday.
    var weekdays: [Int] = []
    var startMinuteOfDay: Int = 0
    var endMinuteOfDay: Int = 0
    var isEnabled: Bool = true
    var blockListID: UUID?

    init(name: String, weekdays: [Int], startMinuteOfDay: Int, endMinuteOfDay: Int) {
        self.name = name
        self.weekdays = weekdays
        self.startMinuteOfDay = startMinuteOfDay
        self.endMinuteOfDay = endMinuteOfDay
    }
}
