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
            // The denied line lands on the screen that fixes it, not the
            // settings root (v1.8 friction pass).
            router.push(showsDeniedNotice ? .settingsPermission : .focus)
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
            Text("screen time off · focus won't shield · settings")
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
        } else if let next = nextScheduleLine() {
            Text(next)
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

    /// Earliest upcoming start across every enabled schedule — one voice
    /// shared with the widget snapshot builder (NextScheduleText).
    private func nextScheduleLine() -> String? {
        NextScheduleText.line(
            schedules: schedules.map {
                NextScheduleText.Candidate(
                    name: $0.name,
                    weekdays: $0.weekdays,
                    startMinuteOfDay: $0.startMinuteOfDay
                )
            },
            after: ClockProvider.now()
        )
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
