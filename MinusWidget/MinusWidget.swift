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
}

// MARK: - Launcher

struct LauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> LauncherEntry {
        LauncherEntry(date: .now, snapshot: .fixture)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (LauncherEntry) -> Void) {
        completion(LauncherEntry(date: .now, snapshot: LauncherSnapshot.read() ?? .fixture))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<LauncherEntry>) -> Void) {
        completion(Timeline(entries: [LauncherEntry(date: .now, snapshot: LauncherSnapshot.read())], policy: .never))
    }
}

struct LauncherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MinusLauncher", provider: LauncherProvider()) { entry in
            LauncherFamilyView(snapshot: entry.snapshot)
                .modifier(GlassAwareBackground())
        }
        .configurationDisplayName("launcher")
        .description("your essentials, one tap.")
        .supportedFamilies(Self.launcherFamilies)
    }

    /// The iPhone full-home-page family is `systemExtraLargePortrait`,
    /// iOS-available only in SDK 27 — the compiler gate keeps this file
    /// building under the stable 26.4 suite toolchain while the SDK-27 device
    /// binary declares the full page.
    static var launcherFamilies: [WidgetFamily] {
        var families: [WidgetFamily] = [.systemMedium, .systemLarge, .systemExtraLarge]
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
    var snapshot: LauncherSnapshot?

    var body: some View {
        LauncherWidgetView(snapshot: snapshot, layout: layout)
    }

    private var layout: LauncherLayout {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *), family == .systemExtraLargePortrait {
            return .page
        }
        #endif
        switch family {
        case .systemExtraLarge: return .page
        case .systemLarge: return .column
        default: return .compact
        }
    }
}

// MARK: - Focus

struct FocusProvider: TimelineProvider {
    func placeholder(in context: Context) -> LauncherEntry {
        LauncherEntry(date: .now, snapshot: .fixture)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (LauncherEntry) -> Void) {
        completion(LauncherEntry(date: .now, snapshot: LauncherSnapshot.read() ?? .fixture))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<LauncherEntry>) -> Void) {
        let snapshot = LauncherSnapshot.read()
        var entries = [LauncherEntry(date: .now, snapshot: snapshot)]
        // Self-flip: re-render the same snapshot the moment a session ends, so
        // the widget shows next/idle on time with no extension write (W-4).
        if let until = snapshot?.focus.activeUntil, until > .now {
            entries.append(LauncherEntry(date: until, snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct FocusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MinusFocus", provider: FocusProvider()) { entry in
            FocusWidgetView(snapshot: entry.snapshot, now: entry.date)
                .widgetURL(URL(string: "minus://focus"))
                .modifier(GlassAwareBackground())
        }
        .configurationDisplayName("focus")
        .description("where focus stands.")
        .supportedFamilies([.systemSmall])
    }
}
