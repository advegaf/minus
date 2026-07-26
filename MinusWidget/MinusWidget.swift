import SwiftUI
import WidgetKit

// The only file that imports WidgetKit. Stateless providers, Sendable entries,
// timeline policy .never — LauncherBridge.publish's reloadAllTimelines is the
// sole refresh signal, plus one self-flip entry at a session's planned end so
// the focus widget goes idle on time even when minus is dead.

@main
struct MinusWidgetBundle: WidgetBundle {
    var body: some Widget {
        LauncherWidget()
        FocusWidget()
    }
}

struct LauncherEntry: TimelineEntry, Sendable {
    var date: Date
    var snapshot: LauncherSnapshot?
    /// Carried on the entry rather than read inside the view, so an archived
    /// render stays deterministic and the in-app gallery (which renders these
    /// same views) never reaches for the app group.
    var typeface: MTypeface = .fallback
}

// MARK: - Launcher

/// v1.6 entry: PLAIN values only — the configuration intent is not Sendable
/// and never crosses into the entry.
struct ConfiguredLauncherEntry: TimelineEntry, Sendable {
    var date: Date
    var snapshot: LauncherSnapshot?
    var cardID: UUID?
    var textSize: LauncherTextSize
    var alignment: LauncherCellAlignment
    /// The user's typeface, read from the app group at timeline time.
    var typeface: MTypeface = .fallback

    static func from(_ configuration: LauncherConfigIntent, snapshot: LauncherSnapshot?) -> Self {
        ConfiguredLauncherEntry(
            date: .now,
            snapshot: snapshot,
            cardID: configuration.card?.id,
            textSize: configuration.textSize,
            alignment: configuration.alignment,
            typeface: MTypeface.published
        )
    }
}

struct LauncherProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ConfiguredLauncherEntry {
        ConfiguredLauncherEntry(
            date: .now,
            snapshot: .fixture,
            cardID: nil,
            textSize: .medium,
            alignment: .leading,
            typeface: MTypeface.published
        )
    }

    func snapshot(for configuration: LauncherConfigIntent, in context: Context) async -> ConfiguredLauncherEntry {
        .from(configuration, snapshot: LauncherSnapshot.read() ?? .fixture)
    }

    func timeline(for configuration: LauncherConfigIntent, in context: Context) async -> Timeline<ConfiguredLauncherEntry> {
        Timeline(entries: [.from(configuration, snapshot: LauncherSnapshot.read())], policy: .never)
    }
}

struct LauncherWidget: Widget {
    var body: some WidgetConfiguration {
        // SAME kind as the v1.5 StaticConfiguration — placed widgets survive
        // the upgrade and render with defaults until the user edits them.
        AppIntentConfiguration(
            kind: "MinusLauncher",
            intent: LauncherConfigIntent.self,
            provider: LauncherProvider()
        ) { entry in
            LauncherFamilyView(entry: entry)
                .environment(\.mnTypeface, entry.typeface)
                .modifier(GlassAwareBackground())
        }
        .configurationDisplayName("launcher")
        .description("your cards, one tap each.")
        .supportedFamilies(Self.launcherFamilies)
    }

    /// v1.6 (D-D): two sizes — large + the full home page. The iPhone
    /// full-page family is `systemExtraLargePortrait`, iOS-available only in
    /// SDK 27 — the compiler gate keeps this file building under the stable
    /// 26.4 toolchain while the SDK-27 binary declares the page.
    static var launcherFamilies: [WidgetFamily] {
        var families: [WidgetFamily] = [.systemLarge]
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            families.append(.systemExtraLargePortrait)
        }
        #endif
        return families
    }
}

/// Family-aware wrapper: the shared view stays WidgetKit-free, so the family
/// read happens here.
private struct LauncherFamilyView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ConfiguredLauncherEntry

    var body: some View {
        LauncherWidgetView(
            snapshot: entry.snapshot,
            layout: layout,
            cardID: entry.cardID,
            textSize: entry.textSize,
            alignment: entry.alignment
        )
    }

    private var layout: LauncherLayout {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *), family == .systemExtraLargePortrait {
            return .page
        }
        #endif
        return .column
    }
}

// MARK: - Focus

struct FocusProvider: TimelineProvider {
    func placeholder(in context: Context) -> LauncherEntry {
        LauncherEntry(date: .now, snapshot: .fixture, typeface: MTypeface.published)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (LauncherEntry) -> Void) {
        completion(LauncherEntry(date: .now, snapshot: LauncherSnapshot.read() ?? .fixture, typeface: MTypeface.published))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<LauncherEntry>) -> Void) {
        let snapshot = LauncherSnapshot.read()
        let face = MTypeface.published
        var entries = [LauncherEntry(date: .now, snapshot: snapshot, typeface: face)]
        // Self-flip: re-render the same snapshot the moment a session ends, so
        // the widget shows next/idle on time with no extension write (W-4).
        if let until = snapshot?.focus.activeUntil, until > .now {
            entries.append(LauncherEntry(date: until, snapshot: snapshot, typeface: face))
        }
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct FocusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MinusFocus", provider: FocusProvider()) { entry in
            FocusWidgetView(snapshot: entry.snapshot, now: entry.date)
                .environment(\.mnTypeface, entry.typeface)
                .widgetURL(URL(string: "minus://focus"))
                .modifier(GlassAwareBackground())
        }
        .configurationDisplayName("focus")
        .description("where focus stands.")
        .supportedFamilies([.systemSmall])
    }
}
