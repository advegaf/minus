import Foundation
import SwiftData
import UIKit
import WidgetKit

/// The single publisher of LauncherSnapshot and the ONLY caller of
/// WidgetCenter.reloadAllTimelines in the codebase. Wired at two choke points:
/// MinusApp's scenePhase transitions and SessionCoordinator.onStateChange.
@MainActor
enum LauncherBridge {
    /// Pure builder — everything injected, unit-testable.
    static func snapshot(
        essentials: [EssentialApp],
        intention: String,
        activeSnapshot: ActivitySnapshot?,
        schedules: [FocusSchedule],
        now: Date,
        installedCheck: (URL) -> Bool
    ) -> LauncherSnapshot {
        let items = essentials.map { app in
            LauncherSnapshot.Essential(
                slug: app.slug,
                name: app.displayName,
                url: app.urlScheme,
                installed: URL(string: app.urlScheme).map(installedCheck)
            )
        }
        let next = NextScheduleText.line(
            schedules: schedules.map {
                NextScheduleText.Candidate(
                    name: $0.name,
                    weekdays: $0.weekdays,
                    startMinuteOfDay: $0.startMinuteOfDay
                )
            },
            after: now
        )
        return LauncherSnapshot(
            essentials: items,
            intention: intention,
            focus: LauncherSnapshot.FocusState(
                activeUntil: activeSnapshot?.plannedEndAt,
                nextSchedule: next
            ),
            generatedAt: now
        )
    }

    /// Fetch, build, write, reload. In UITestMode the file is deleted instead —
    /// per-launch isolation, same contract as SharedState.reset().
    static func publish(context: ModelContext, coordinator: SessionCoordinator) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestMode") {
            LauncherSnapshot.delete()
            return
        }
        #endif
        var essentialsDescriptor = FetchDescriptor<EssentialApp>(sortBy: [SortDescriptor(\.sortOrder)])
        essentialsDescriptor.predicate = #Predicate { $0.isEnabled }
        let essentials = (try? context.fetch(essentialsDescriptor)) ?? []
        let intention = MinusContainer.userConfig(in: context).intentionText
        let schedules = (try? context.fetch(
            FetchDescriptor<FocusSchedule>(predicate: #Predicate { $0.isEnabled })
        )) ?? []

        snapshot(
            essentials: essentials,
            intention: intention,
            activeSnapshot: coordinator.activeSnapshot,
            schedules: schedules,
            now: ClockProvider.now(),
            installedCheck: { UIApplication.shared.canOpenURL($0) }
        ).write()

        WidgetCenter.shared.reloadAllTimelines()
    }
}
