import SwiftUI

// Widget content views — compiled into BOTH targets: the widget renders them
// on the home screen, DesignGallery renders them for the screenshot loop, and
// DesignGuardTests scans them. SwiftUI-only (Link is SwiftUI); no WidgetKit
// import, no ClockProvider — time comes in as a plain `now` parameter.
//
// v1.2 restyle (reference-driven): the launcher is a big airy left-aligned
// text stack on the void — NO hairlines anywhere; air is the separator.

/// Layout family abstraction so this file needn't import WidgetKit.
enum LauncherLayout {
    /// systemMedium: single column, up to four names.
    case compact
    /// systemLarge: single column, up to seven, wider gaps.
    case column
    /// systemExtraLarge (iOS 27 full home page): the dumb phone itself —
    /// names at headingLg with sculptural spacing, intention as the footer.
    case page
}

/// The home launcher: essential apps as tappable text that trampolines
/// through minus://open/{slug}.
struct LauncherWidgetView: View {
    var snapshot: LauncherSnapshot?
    var layout: LauncherLayout

    var body: some View {
        if let snapshot, !snapshot.essentials.isEmpty {
            content(snapshot)
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

    private func spec(for layout: LauncherLayout) -> Spec {
        switch layout {
        case .compact: Spec(cap: 4, token: .bodyLg, rowSpacing: MN.Space.xxs, minRow: 34)
        case .column: Spec(cap: 7, token: .bodyLg, rowSpacing: MN.Space.s, minRow: 40)
        case .page: Spec(cap: 7, token: .headingLg, rowSpacing: MN.Space.l, minRow: 48)
        }
    }

    @ViewBuilder
    private func content(_ snapshot: LauncherSnapshot) -> some View {
        let spec = spec(for: layout)
        VStack(alignment: .leading, spacing: spec.rowSpacing) {
            if layout == .page {
                Spacer(minLength: MN.Space.m)
            }
            ForEach(snapshot.essentials.prefix(spec.cap)) { essential in
                cell(essential, token: spec.token, minRow: spec.minRow)
            }
            Spacer(minLength: 0)
            if layout != .compact, !snapshot.intention.isEmpty {
                Text(snapshot.intention)
                    .mnType(.caption)
                    .foregroundStyle(MN.fogBlue)
                    .lineLimit(1)
                    .padding(.bottom, layout == .page ? MN.Space.m : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func cell(_ essential: LauncherSnapshot.Essential, token: MNType, minRow: CGFloat) -> some View {
        Link(destination: URL(string: "minus://open/\(essential.slug)") ?? URL(string: "minus://focus")!) {
            Text(essential.name.lowercased())
                .mnType(token)
                .foregroundStyle(MN.boneWhite)
                .opacity(essential.installed == false ? 0.4 : 1)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: minRow, alignment: .leading)
        }
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
