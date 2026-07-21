import SwiftUI

// Widget content views — compiled into BOTH targets: the widget renders them
// on the home screen, DesignGallery renders them for the screenshot loop, and
// DesignGuardTests scans them. SwiftUI-only (Link is SwiftUI); no WidgetKit
// import, no ClockProvider — time comes in as a plain `now` parameter.

/// Layout family abstraction so this file needn't import WidgetKit.
enum LauncherLayout {
    /// systemMedium: two columns, up to six cells.
    case grid
    /// systemLarge: one column, up to seven cells, intention footer.
    case column
}

/// The home launcher, shrunk: essential apps as tappable text cells that
/// trampoline through minus://open/{slug}.
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

    @ViewBuilder
    private func content(_ snapshot: LauncherSnapshot) -> some View {
        switch layout {
        case .grid:
            let cells = Array(snapshot.essentials.prefix(6))
            let rows = stride(from: 0, to: cells.count, by: 2).map { Array(cells[$0..<min($0 + 2, cells.count)]) }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: MN.Space.s) {
                        ForEach(row) { essential in
                            cell(essential)
                        }
                        if row.count == 1 {
                            Spacer(minLength: 0)
                        }
                    }
                    if index < rows.count - 1 {
                        Rectangle().fill(MN.ashBorder).frame(height: MN.hairline)
                    }
                }
            }
        case .column:
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(snapshot.essentials.prefix(7).enumerated()), id: \.element.id) { index, essential in
                    if index > 0 {
                        Rectangle().fill(MN.ashBorder).frame(height: MN.hairline)
                    }
                    cell(essential)
                }
                if !snapshot.intention.isEmpty {
                    Spacer(minLength: MN.Space.xs)
                    Text(snapshot.intention)
                        .mnType(.caption)
                        .foregroundStyle(MN.fogBlue)
                        .lineLimit(1)
                }
            }
        }
    }

    private func cell(_ essential: LauncherSnapshot.Essential) -> some View {
        Link(destination: URL(string: "minus://open/\(essential.slug)") ?? URL(string: "minus://focus")!) {
            Text(essential.name.lowercased())
                .mnType(.bodyLg)
                .foregroundStyle(MN.boneWhite)
                .opacity(essential.installed == false ? 0.4 : 1)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
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
            Text(next)
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
