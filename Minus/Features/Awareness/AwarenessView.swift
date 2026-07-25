import DeviceActivity
import SwiftData
import SwiftUI

/// Awareness: what focus gave back, derived live from session rows — plus the
/// device's own truth (screen time, pickups) rendered by the sandboxed report
/// extension on hardware. The simulator says so instead of pretending.
struct AwarenessView: View {
    @Environment(AppDependencies.self) private var deps
    @Query private var sessions: [FocusSession]

    private var slices: [SessionSlice] {
        sessions.map {
            SessionSlice(
                startedAt: $0.startedAt,
                endedAt: $0.endedAt,
                plannedEndAt: $0.plannedEndAt,
                wasCompleted: $0.endReason == .completed
            )
        }
    }

    private var hasAnyHistory: Bool {
        !sessions.isEmpty
    }

    var body: some View {
        ZStack {
            MN.obsidian.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PushedHeader(eyebrow: "AWARENESS")

                    if hasAnyHistory {
                        stats
                    } else {
                        zeroState
                    }

                    ReportSection()
                        .padding(.top, MN.Space.section)
                        .padding(.bottom, MN.Space.l)
                }
                .padding(.horizontal, MN.Space.m)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("awareness")
    }

    private var stats: some View {
        let now = ClockProvider.now()
        return VStack(alignment: .leading, spacing: MN.Space.l) {
            stat(
                label: "focused today",
                value: StatsService.shortDuration(StatsService.focusSeconds(on: now, sessions: slices, now: now)),
                id: "stat-today"
            )
            stat(
                label: "this week",
                value: StatsService.shortDuration(StatsService.weekSeconds(ending: now, sessions: slices, now: now)),
                id: "stat-week"
            )
            stat(
                label: "streak",
                value: streakText,
                id: "stat-streak"
            )
        }
        .padding(.top, MN.Space.l)
    }

    private var streakText: String {
        let days = StreakService.currentStreak(sessions: slices, today: ClockProvider.now())
        return days == 1 ? "1 day" : "\(days) days"
    }

    private func stat(label: String, value: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: MN.Space.xxs) {
            Text(label)
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.fogBlue)
            Text(value)
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

    private var zeroState: some View {
        VStack(alignment: .leading, spacing: MN.Space.s) {
            Text("Nothing yet.")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)
            Text("your first focus session paints this page.")
                .mnType(.body)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)
        }
        .padding(.top, MN.Space.l)
        .accessibilityIdentifier("awareness-zero")
    }
}

/// Hosts the DeviceActivityReport on hardware; on the simulator (or with a
/// mock service) it renders an honest placeholder — never fake numbers.
struct ReportSection: View {
    @Environment(AppDependencies.self) private var deps

    var body: some View {
        VStack(alignment: .leading, spacing: MN.Space.s) {
            Text("your phone today")
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.fogBlue)
                .accessibilityIdentifier("report-eyebrow")

            Text("from apple screen time. minus never sees these numbers.")
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)

            if deps.service.isMock {
                placeholder
            } else if deps.service.authorizationStatus != .approved {
                denied
            } else {
                report
            }
        }
        // A container identifier here swallows the child ids the tests query.
        // Status is read once at launch; a grant or a revoke made since then
        // would otherwise route a denied user into an empty report host.
        .onAppear { deps.service.refreshAuthorizationStatus() }
    }

    /// The report host paints its own opaque obsidian canvas, so the honest
    /// line underneath is only ever visible when the extension does not render
    /// at all. Without it the section is a word above 160pt of void.
    private var report: some View {
        ZStack(alignment: .topLeading) {
            Text("no numbers yet today.")
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
                .accessibilityIdentifier("report-empty")
            DeviceActivityReport(.dailyOverview, filter: Self.todayFilter)
                .accessibilityIdentifier("device-report")
        }
        .frame(height: 160)
    }

    private static var todayFilter: DeviceActivityFilter {
        DeviceActivityFilter(
            segment: .daily(during: Calendar.current.dateInterval(of: .day, for: Date()) ?? DateInterval()),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: MN.Space.xs) {
            PillTag("Simulator")
            Text("screen time and pickups render from device data. the simulator has none.")
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)
        }
        .accessibilityIdentifier("report-placeholder")
    }

    private var denied: some View {
        Text("screen time access is off. turn it on in settings to see device totals.")
            .mnType(.caption)
            .foregroundStyle(MN.fogBlue)
            .frame(maxWidth: 320, alignment: .leading)
            .accessibilityIdentifier("report-denied")
    }
}

extension DeviceActivityReport.Context {
    /// Must match the context declared inside MinusReport (the extension and
    /// host bind scenes by this raw value).
    static let dailyOverview = Self("Daily Overview")
}
