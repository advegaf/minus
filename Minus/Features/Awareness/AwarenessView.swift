import DeviceActivity
import SwiftData
import SwiftUI

/// Awareness: what focus gave back, derived live from session rows — plus the
/// device's own truth (screen time, pickups) rendered by the sandboxed report
/// extension on hardware. The simulator says so instead of pretending.
struct AwarenessView: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var sessions: [FocusSession]

    /// First paint only, in the vocabulary every other screen already speaks.
    /// One-way, because the @Query can resolve late and swap the stats and
    /// zero branches under a re-render, and an entrance that replays reads
    /// as a glitch.
    @State private var appeared = false

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
                            .entering(0, appeared: appeared, reduceMotion: reduceMotion)
                    }

                    // Last in the stagger: the honest line fades in with the
                    // stats, and the extension's panel crossfades over it a
                    // second later instead of blinking into a settled screen.
                    ReportSection()
                        .padding(.top, MN.Space.section)
                        .padding(.bottom, MN.Space.l)
                        .entering(3, appeared: appeared, reduceMotion: reduceMotion)
                }
                .padding(.horizontal, MN.Space.m)
                .onAppear { appeared = true }
                .task { appeared = true }
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
                id: "stat-today",
                index: 0
            )
            stat(
                label: "this week",
                value: StatsService.shortDuration(StatsService.weekSeconds(ending: now, sessions: slices, now: now)),
                id: "stat-week",
                index: 1
            )
            stat(
                label: "streak",
                value: streakText,
                id: "stat-streak",
                index: 2
            )
        }
        .padding(.top, MN.Space.l)
    }

    private var streakText: String {
        let days = StreakService.currentStreak(sessions: slices, today: ClockProvider.now())
        return days == 1 ? "1 day" : "\(days) days"
    }

    private func stat(label: String, value: String, id: String, index: Int) -> some View {
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
        .entering(index, appeared: appeared, reduceMotion: reduceMotion)
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

/// The launcher's entrance, borrowed verbatim: 6pt rise on MMotion.micro,
/// one staggerStep per block. Reduce motion collapses it to no offset and no
/// delay, the same trade every other screen makes.
private struct Entering: ViewModifier {
    let index: Int
    let appeared: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity((appeared || reduceMotion) ? 1 : 0)
            .offset(y: (appeared || reduceMotion) ? 0 : 6)
            .animation(
                MMotion.settle(
                    MMotion.micro.delay(Double(index) * MMotion.staggerStep),
                    reduceMotion: reduceMotion
                ),
                value: appeared
            )
    }
}

private extension View {
    func entering(_ index: Int, appeared: Bool, reduceMotion: Bool) -> some View {
        modifier(Entering(index: index, appeared: appeared, reduceMotion: reduceMotion))
    }
}

/// Hosts the DeviceActivityReport on hardware; on the simulator (or with a
/// mock service) it renders an honest placeholder — never fake numbers.
struct ReportSection: View {
    @Environment(AppDependencies.self) private var deps

    var body: some View {
        VStack(alignment: .leading, spacing: MN.Space.s) {
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
