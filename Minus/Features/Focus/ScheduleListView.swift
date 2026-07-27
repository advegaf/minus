import SwiftData
import SwiftUI

/// Recurring block windows. Rows carry their enabled state in color (the
/// selection-row vocabulary); the ghost on/off toggles registration through
/// the coordinator so DeviceActivity stays in lockstep with SwiftData.
struct ScheduleListView: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(AppRouter.self) private var router
    @Query(sort: \FocusSchedule.startMinuteOfDay) private var schedules: [FocusSchedule]

    @State private var toggleError: String?

    private var defaultBlockList: BlockList? {
        (try? deps.context.fetch(FetchDescriptor<BlockList>(predicate: #Predicate { $0.isDefault })))?.first
    }

    var body: some View {
        ZStack {
            MN.obsidian.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                PushedHeader(eyebrow: "SCHEDULES")

                // Scrolls (F-D): saved schedules are unbounded — only enabling
                // is budget-capped — so the list must never push the CTA away.
                ScrollView {
                    if schedules.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        list
                    }
                }

                Spacer(minLength: MN.Space.s)

                if let toggleError {
                    Text(toggleError)
                        .mnType(.caption)
                        .foregroundStyle(MN.fogBlue)
                        .padding(.bottom, MN.Space.xs)
                        .accessibilityIdentifier("schedule-error")
                }

                OutlinedCTA(title: "New schedule", prominent: true) {
                    router.push(.scheduleEditor(id: nil))
                }
                .accessibilityIdentifier("cta-new-schedule")
                .padding(.bottom, MN.Space.m)
            }
            .padding(.horizontal, MN.Space.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("schedule-list")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: MN.Space.s) {
            Text("No schedules yet.")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)
            Text("windows of time when blocked apps stay blocked, every week, without asking.")
                .mnType(.body)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)
        }
        .padding(.top, MN.Space.l)
        .accessibilityIdentifier("schedules-empty")
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(schedules) { schedule in
                row(for: schedule)
            }
        }
        .padding(.top, MN.Space.l)
    }

    private func row(for schedule: FocusSchedule) -> some View {
        HStack(alignment: .center, spacing: MN.Space.s) {
            Button {
                router.push(.scheduleEditor(id: schedule.id))
            } label: {
                VStack(alignment: .leading, spacing: MN.Space.xxs) {
                    Text(schedule.name.isEmpty ? "focus" : schedule.name.lowercased())
                        .mnType(.bodyLg)
                        .foregroundStyle(schedule.isEnabled ? MN.boneWhite : MN.fogBlue)
                    Text("\(Self.dayText(schedule.weekdays)) · \(Self.windowText(schedule))")
                        .mnType(.caption)
                        .foregroundStyle(MN.fogBlue)
                }
                .frame(maxWidth: .infinity, minHeight: MN.minHit, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.mnPress)
            .accessibilityIdentifier("row-schedule-\(schedule.id.uuidString)")

            GhostCaptionButton(
                title: schedule.isEnabled ? "on" : "off",
                accessibilityID: "toggle-schedule-\(schedule.id.uuidString)"
            ) {
                toggle(schedule)
            }
            .frame(width: 64)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(MN.ashBorder).frame(height: MN.hairline)
        }
    }

    private func toggle(_ schedule: FocusSchedule) {
        toggleError = nil
        if schedule.isEnabled {
            deps.coordinator.unregister(schedule: schedule)
            schedule.isEnabled = false
        } else {
            guard let blockList = defaultBlockList else {
                toggleError = "choose blocked apps first"
                return
            }
            do {
                try deps.coordinator.register(schedule: schedule, blockList: blockList)
                schedule.isEnabled = true
            } catch {
                toggleError = "couldn't enable. schedule limit reached"
            }
        }
        try? deps.context.save()
    }

    // MARK: Formatting

    static func dayText(_ weekdays: [Int]) -> String {
        let names = [1: "sun", 2: "mon", 3: "tue", 4: "wed", 5: "thu", 6: "fri", 7: "sat"]
        if Set(weekdays) == Set(1...7) { return "every day" }
        // Human order monday-first.
        let ordered = [2, 3, 4, 5, 6, 7, 1].filter { weekdays.contains($0) }
        return ordered.compactMap { names[$0] }.joined(separator: " ")
    }

    static func windowText(_ schedule: FocusSchedule) -> String {
        // "0:00 to 23:59" is the same fact, said the long way.
        if ScheduleMath.isAllDay(
            startMinuteOfDay: schedule.startMinuteOfDay,
            endMinuteOfDay: schedule.endMinuteOfDay
        ) {
            return "all day"
        }
        return "\(timeText(schedule.startMinuteOfDay)) to \(timeText(schedule.endMinuteOfDay))"
    }

    static func timeText(_ minuteOfDay: Int) -> String {
        String(format: "%d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }
}
