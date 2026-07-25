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
    /// v1.12: the app's identity, resolved from the App Store when the entry
    /// was added. This is what makes an added app launch like a catalog one
    /// rather than depending on a Shortcut the user has to build.
    var bundleID: String?
    /// v1.16: the user typed this name themselves. Nothing automatic may
    /// overwrite such a row, or a rename would be undone by the next launch.
    var nameIsCustom: Bool = false

    init(slug: String, displayName: String, urlScheme: String, sortOrder: Int, bundleID: String? = nil) {
        self.slug = slug
        self.displayName = displayName
        self.urlScheme = urlScheme
        self.sortOrder = sortOrder
        self.bundleID = bundleID
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

/// A registry row, flattened for the pure resolvers. Before v1.13 these were
/// passed as [slug: displayName], which had nowhere to put an identity — so
/// the identity an added app resolved from the App Store was silently dropped
/// at every boundary, and the app fell back to a Shortcut the user never made.
struct CustomEntry: Equatable, Sendable {
    var name: String
    var bundleID: String?

    init(name: String, bundleID: String? = nil) {
        self.name = name
        self.bundleID = bundleID
    }
}

/// The name an app wears on the home screen, recovered from the name the App
/// Store sells it under. "MacroFactor - Macro Tracker" is what the store
/// returns; "MacroFactor" is what the icon says, and a launcher should say
/// what the icon says.
///
/// The rule is deliberately narrow. It cuts at a SPACED separator only, which
/// is what makes it safe: "Chick-fil-A", "7-ELEVEN" and "1.1.1.1" carry
/// hyphens and dots inside the name itself and must survive untouched. Checked
/// against the 148 store titles in scripts/catalog-cache.json: 61 shorten, and
/// nothing that should have been left alone was touched.
enum AppName {
    /// Separators only count with space around them. The bare "colon-space"
    /// case is included because "1Password: Password Manager" has no leading
    /// space but is still a tagline.
    /// Built from scalar values rather than written out, because DesignGuard
    /// rule 6 bans em and en dashes inside string literals under Minus/ —
    /// including their escape form, deliberately, so the ban cannot be dodged.
    /// The rule is right and this code is the exception that proves it: these
    /// are characters being parsed OUT of someone else's marketing copy, never
    /// shown, and the guard has no way to tell the difference. Naming them by
    /// code point keeps both things true.
    private static let separators: [String] = {
        let enDash = String(UnicodeScalar(0x2013)!)
        let emDash = String(UnicodeScalar(0x2014)!)
        let middleDot = String(UnicodeScalar(0x00B7)!)
        return [" - ", " \(enDash) ", " \(emDash) ", " : ", " | ", " \(middleDot) ", ": "]
    }()

    static func short(_ title: String) -> String {
        var name = title
        // First separator wins: everything after it is a tagline.
        var cut = name.endIndex
        for separator in separators {
            if let range = name.range(of: separator), range.lowerBound < cut {
                cut = range.lowerBound
            }
        }
        name = String(name[name.startIndex..<cut])

        // A trailing parenthetical is a qualifier, not a name:
        // "Google Health (Fitbit)" is "Google Health" on the home screen.
        if let open = name.lastIndex(of: "("), name.hasSuffix(")") {
            name = String(name[name.startIndex..<open])
        }

        name = name
            .replacingOccurrences(of: "\u{00AE}", with: "")   // ®
            .replacingOccurrences(of: "\u{2122}", with: "")   // ™
            .replacingOccurrences(of: "\u{2120}", with: "")   // ℠
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // A title that was nothing but punctuation keeps whatever it had.
        return name.isEmpty ? title : name
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
