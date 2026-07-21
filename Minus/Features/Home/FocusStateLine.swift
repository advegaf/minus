import SwiftData
import SwiftUI

/// One quiet line above the nav — the single status slot for everything focus.
/// Priority: a live session's countdown, else a revoked-permission notice
/// (routes to Settings), else the next scheduled window, else an invitation to
/// begin. One slot, one height, so the monument above never moves between
/// states (HO-9).
struct FocusStateLine: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(AppRouter.self) private var router

    @Query(filter: #Predicate<FocusSchedule> { $0.isEnabled })
    private var schedules: [FocusSchedule]

    private var showsDeniedNotice: Bool {
        deps.coordinator.activeSnapshot == nil && deps.service.authorizationStatus == .denied
    }

    var body: some View {
        Button {
            router.push(showsDeniedNotice ? .settings : .focus)
        } label: {
            content
                .frame(maxWidth: .infinity, minHeight: MN.minHit, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.mnPress)
        .accessibilityIdentifier(showsDeniedNotice ? "banner-permission" : "focus-state-line")
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = deps.coordinator.activeSnapshot {
            activeCountdown(snapshot)
        } else if showsDeniedNotice {
            Text("screen time off — focus won't shield · settings")
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
        } else if let next = nextSchedule() {
            Text("next · \(next.name) · \(next.when)")
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
        } else {
            Text("begin a focus session")
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
        }
    }

    /// Ticks every second; the remaining interval is derived live from the
    /// snapshot's planned end against `ClockProvider.now()` inside the closure,
    /// so it counts down with real time and freezes when the clock is pinned.
    private func activeCountdown(_ snapshot: ActivitySnapshot) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let remaining = Int(max(0, snapshot.plannedEndAt.timeIntervalSince(ClockProvider.now())))
            let mmss = String(format: "%02d:%02d", remaining / 60, remaining % 60)
            HStack(spacing: 0) {
                Text("focused · ")
                    .mnType(.caption)
                    .foregroundStyle(MN.boneWhite)
                FixedDigits(text: mmss, token: .caption, slot: DigitMetrics.captionSlot)
                Text(" left")
                    .mnType(.caption)
                    .foregroundStyle(MN.boneWhite)
            }
        }
    }

    private struct NextWindow {
        let name: String
        let when: String
    }

    /// Earliest upcoming start across every enabled schedule.
    private func nextSchedule() -> NextWindow? {
        let now = ClockProvider.now()
        var best: (date: Date, name: String)?
        for schedule in schedules {
            guard let date = ScheduleMath.nextOccurrence(
                weekdays: schedule.weekdays,
                startMinuteOfDay: schedule.startMinuteOfDay,
                after: now
            ) else { continue }
            if best == nil || date < best!.date {
                best = (date, schedule.name)
            }
        }
        guard let best else { return nil }
        return NextWindow(name: best.name.lowercased(), when: Self.whenString(best.date))
    }

    /// "mon 9:00" — short weekday plus a 24-hour, non-padded-hour time.
    private static func whenString(_ date: Date) -> String {
        let weekday = DateFormatter()
        weekday.dateFormat = "EEE"
        let time = DateFormatter()
        time.dateFormat = "H:mm"
        return "\(weekday.string(from: date).lowercased()) \(time.string(from: date))"
    }
}

#if DEBUG
#Preview {
    ZStack {
        MN.obsidian.ignoresSafeArea()
        FocusStateLine()
            .padding(MN.Space.m)
    }
    .preferredColorScheme(.dark)
}
#endif
