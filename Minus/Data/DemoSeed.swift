import Foundation
import SwiftData

#if DEBUG
/// Deterministic state seeding for UI tests and screenshot tours, driven by
/// MINUS_STATE (fresh | onboarded | active | schedules | denied). Runs before
/// SessionCoordinator is created so restored snapshots are picked up.
@MainActor
enum DemoSeed {
    static func seedFromEnvironment(context: ModelContext) {
        guard let state = ProcessInfo.processInfo.environment["MINUS_STATE"], state != "fresh" else {
            return
        }
        SharedState.reset()
        seedOnboarded(context: context)
        switch state {
        case "active":
            seedActiveSession(context: context)
        case "schedules":
            seedSchedules(context: context)
        default:
            break
        }
        try? context.save()
    }

    private static func seedOnboarded(context: ModelContext) {
        let config = MinusContainer.userConfig(in: context)
        config.intentionText = "less phone. more life."
        config.onboardedAt = ClockProvider.now().addingTimeInterval(-86_400 * 3)

        for (index, slug) in ["phone", "messages", "maps", "music", "photos"].enumerated() {
            guard let app = EssentialAppCatalog.app(slug: slug) else { continue }
            context.insert(EssentialApp(slug: app.slug, displayName: app.displayName, urlScheme: app.urlString, sortOrder: index))
        }

        let blockList = MinusContainer.defaultBlockList(in: context)
        blockList.selectionData = MockScreenTimeService.encodeSelection(apps: 5, categories: 2)
        blockList.updatedAt = ClockProvider.now()
    }

    private static func seedActiveSession(context: ModelContext) {
        let now = ClockProvider.now()
        let start = now.addingTimeInterval(-5 * 60)
        let end = now.addingTimeInterval(25 * 60)
        let session = FocusSession(startedAt: start, plannedEndAt: end, source: .manual, activityName: "")
        session.activityName = ScheduleMath.manualActivityName(sessionID: session.id)
        context.insert(session)
        SharedState.activeSessions = [
            ActivitySnapshot(activityName: session.activityName, sessionID: session.id, startedAt: start, plannedEndAt: end)
        ]
        // A few finished sessions so Awareness has history.
        for daysAgo in 1...3 {
            let s = now.addingTimeInterval(TimeInterval(-daysAgo) * 86_400)
            let finished = FocusSession(startedAt: s, plannedEndAt: s.addingTimeInterval(45 * 60), source: .manual, activityName: "")
            finished.activityName = ScheduleMath.manualActivityName(sessionID: finished.id)
            finished.endedAt = s.addingTimeInterval(45 * 60)
            finished.endReason = .completed
            context.insert(finished)
        }
    }

    private static func seedSchedules(context: ModelContext) {
        let morning = FocusSchedule(name: "Deep work", weekdays: [2, 3, 4, 5, 6], startMinuteOfDay: 9 * 60, endMinuteOfDay: 11 * 60)
        let evening = FocusSchedule(name: "Wind down", weekdays: [1, 2, 3, 4, 5, 6, 7], startMinuteOfDay: 21 * 60, endMinuteOfDay: 22 * 60 + 30)
        context.insert(morning)
        context.insert(evening)
    }
}
#endif
