import SwiftUI
import WidgetKit

// Widget content views — compiled into BOTH targets: the widget renders them
// on the home screen, DesignGallery renders them for the screenshot loop, and
// DesignGuardTests scans them. No ClockProvider — time comes in as a plain
// `now` parameter. WidgetKit import is for widgetRenderingMode/widgetAccentable
// only (harmless in the app target; the gallery renders fullColor).
//
// v1.2 restyle (reference-driven): the launcher is a big airy left-aligned
// text stack on the void — NO hairlines anywhere; air is the separator.
//
// v1.3 liquid glass (W-glass): in accented rendering (the system's Clear/
// Tinted home-screen styles) the container drops to transparent and every
// glyph is widgetAccentable — the wallpaper penetrates and the launcher reads
// as floating words, not a widget. Full-color keeps the branded obsidian.

/// Mode-aware container: obsidian when full-color, transparent under the
/// system's glass treatments.
struct GlassAwareBackground: ViewModifier {
    @Environment(\.widgetRenderingMode) private var renderingMode

    func body(content: Content) -> some View {
        content.containerBackground(for: .widget) {
            if renderingMode == .fullColor {
                // True black, not obsidian: on a pure-black wallpaper the
                // container edge vanishes entirely (v1.5 premium ask).
                Color.black
            } else {
                Color.clear
            }
        }
    }
}

/// Layout family abstraction so this file needn't import WidgetKit.
/// v1.6 (D-D): two sizes only — medium and the iPad XL are gone.
enum LauncherLayout {
    /// systemLarge: single column, up to seven.
    case column
    /// systemExtraLargePortrait (iOS 27 full home page): the dumb phone
    /// itself — sculptural spacing, intention as the footer.
    case page
}

/// The home launcher: one card's apps as tappable text, zero-hop launched.
/// v1.6 (D-B/D-C): per-instance card + text size + placement from Edit Widget.
struct LauncherWidgetView: View {
    var snapshot: LauncherSnapshot?
    var layout: LauncherLayout
    var cardID: UUID?
    var textSize: LauncherTextSize = .medium
    var alignment: LauncherCellAlignment = .leading

    private var card: LauncherSnapshot.Card? {
        snapshot?.card(id: cardID)
    }

    var body: some View {
        if let card, !card.essentials.isEmpty {
            content(card, intention: snapshot?.intention ?? "")
        } else {
            EmptyInviteView()
        }
    }

    private struct Spec {
        var cap: Int
        var token: MNType
        var rowSpacing: CGFloat
        var minRow: CGFloat
    }

    /// The size matrix (D-B). Column: 17/22/28. Page: 28/40/64.
    private func baseSpec() -> Spec {
        switch (layout, textSize) {
        case (.column, .small): Spec(cap: 7, token: .body, rowSpacing: MN.Space.xxs, minRow: 32)
        case (.column, .medium): Spec(cap: 7, token: .bodyLg, rowSpacing: MN.Space.s, minRow: 40)
        case (.column, .large): Spec(cap: 7, token: .bodyXl, rowSpacing: MN.Space.xs, minRow: 46)
        case (.page, .small): Spec(cap: 7, token: .bodyXl, rowSpacing: MN.Space.m, minRow: 40)
        case (.page, .medium): Spec(cap: 7, token: .headingLg, rowSpacing: MN.Space.l, minRow: 48)
        case (.page, .large): Spec(cap: 7, token: .displaySm, rowSpacing: MN.Space.m, minRow: 72)
        }
    }

    /// Density audit (D-E): the canvases are fixed, so a six-or-seven-app card
    /// tightens spacing, and at .large steps the type down one notch — every
    /// chosen app always renders; nothing silently clips or drops.
    /// (7 × 64pt ≈ 775pt against the page's ~680; 7 × 22pt was already
    /// borderline in the v1.5 column.)
    private func spec(count: Int) -> Spec {
        var spec = baseSpec()
        guard count >= 6 else { return spec }
        spec.rowSpacing = min(spec.rowSpacing, layout == .page ? MN.Space.xs : MN.Space.xxs)
        if textSize == .large {
            spec.token = layout == .page ? .headingLg : .bodyLg
            spec.minRow = layout == .page ? 48 : 40
        }
        return spec
    }

    private var stackAlignment: HorizontalAlignment {
        alignment == .center ? .center : .leading
    }

    private var cellAlignment: Alignment {
        alignment == .center ? .center : .leading
    }

    @ViewBuilder
    private func content(_ card: LauncherSnapshot.Card, intention: String) -> some View {
        let spec = spec(count: card.essentials.count)
        VStack(alignment: stackAlignment, spacing: spec.rowSpacing) {
            if layout == .page {
                Spacer(minLength: MN.Space.l)
            }
            ForEach(card.essentials.prefix(spec.cap)) { essential in
                cell(essential, spec: spec)
            }
            if layout == .page {
                Spacer(minLength: MN.Space.l)
            } else {
                Spacer(minLength: 0)
            }
            if !intention.isEmpty {
                Text(intention)
                    .mnType(.caption)
                    .foregroundStyle(MN.fogBlue)
                    .widgetAccentable()
                    .lineLimit(1)
                    .padding(.bottom, layout == .page ? MN.Space.m : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment == .center ? .top : .topLeading)
    }

    /// Two cell shapes, because a widget's powers depend on the URL.
    ///
    /// https target: `Button(intent:)` runs LaunchEssentialIntent in the
    /// widget process and the SYSTEM opens it, so minus never launches. This
    /// is the zero-hop path, and universal links are the ONLY thing App
    /// Intents can open.
    ///
    /// Anything else (custom schemes, the Shortcuts route): `Link` bounces
    /// through minus, which walks the full launch plan behind a black veil.
    /// v1.8 handed custom schemes to OpenURLIntent, which silently refuses
    /// them, which is why third-party taps did nothing on device.
    @ViewBuilder
    private func cell(_ essential: LauncherSnapshot.Essential, spec: Spec) -> some View {
        let target = essential.target ?? essential.url
        if target.hasPrefix("https") {
            Button(intent: LaunchEssentialIntent(slug: essential.slug, urlString: target)) {
                label(essential, spec: spec)
            }
            .buttonStyle(.plain)
        } else {
            Link(destination: URL(string: "minus://open/\(essential.slug)") ?? Self.focusURL) {
                label(essential, spec: spec)
            }
        }
    }

    private static let focusURL = URL(string: "minus://focus")!

    private func label(_ essential: LauncherSnapshot.Essential, spec: Spec) -> some View {
        Text(essential.name.lowercased())
            .mnType(spec.token)
            .foregroundStyle(MN.boneWhite)
            .widgetAccentable()
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: spec.minRow, alignment: cellAlignment)
    }
}

/// The status slot, elevated: where focus stands right now. Time semantics
/// come from the caller (`entry.date` in the widget, fixtures in the gallery).
struct FocusWidgetView: View {
    var snapshot: LauncherSnapshot?
    var now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: MN.Space.xs) {
            if let snapshot {
                content(snapshot)
            } else {
                EmptyInviteView()
            }
        }
        .widgetAccentable()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func content(_ snapshot: LauncherSnapshot) -> some View {
        if let until = snapshot.focus.activeUntil, now < until {
            Text("FOCUSED")
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.fogBlue)
            Text("until \(Self.timeText(until))")
                .mnType(.bodyLg)
                .foregroundStyle(MN.boneWhite)
        } else if let next = snapshot.focus.nextSchedule {
            Text("NEXT")
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.fogBlue)
            // The eyebrow already says NEXT — drop the line's own prefix.
            Text(next.replacingOccurrences(of: "next \u{00B7} ", with: ""))
                .mnType(.body)
                .foregroundStyle(MN.boneWhite)
                .lineLimit(3)
        } else if !snapshot.intention.isEmpty {
            Text(snapshot.intention)
                .mnType(.body)
                .foregroundStyle(MN.boneWhite)
        } else {
            Text("begin a focus session")
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
        }
    }

    static func timeText(_ date: Date) -> String {
        let c = Calendar.current
        return String(format: "%02d:%02d", c.component(.hour, from: date), c.component(.minute, from: date))
    }
}

/// Fresh install / post-reset: the widget invites setup instead of sitting blank.
struct EmptyInviteView: View {
    var body: some View {
        Text("open minus")
            .mnType(.caption)
            .foregroundStyle(MN.fogBlue)
            .widgetAccentable()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
