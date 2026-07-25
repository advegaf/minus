import Foundation
import SwiftData
import WidgetKit

/// The single publisher of LauncherSnapshot and the ONLY caller of
/// WidgetCenter.reloadAllTimelines in the codebase. Wired at two choke points:
/// MinusApp's scenePhase transitions and SessionCoordinator.onStateChange.
@MainActor
enum LauncherBridge {
    /// What a card looks like before slugs are resolved — plain values so the
    /// builder stays pure and unit-testable.
    struct CardInput {
        var id: UUID
        var name: String
        var orderedSlugs: [String]
    }

    /// Pure builder, everything injected. Slug resolution: catalog rows get
    /// their compiled-in name and url, "custom-" slugs resolve from the
    /// registry. v1.8: `installed` is always nil. minus asks nobody whether an
    /// app exists before offering to open it (see EssentialLauncher).
    static func snapshot(
        cards: [CardInput],
        customEntries: [String: String],
        intention: String,
        activeSnapshot: ActivitySnapshot?,
        schedules: [FocusSchedule],
        now: Date
    ) -> LauncherSnapshot {
        func resolve(_ slug: String) -> LauncherSnapshot.Essential? {
            if let app = EssentialAppCatalog.app(slug: slug) {
                let target = EssentialLaunchURL.widgetTarget(
                    slug: slug,
                    urlString: app.urlString,
                    universalLink: app.universalLink,
                    linkVerified: app.linkVerified
                )
                return LauncherSnapshot.Essential(
                    slug: slug,
                    name: app.displayName,
                    url: app.urlString,
                    target: target?.absoluteString,
                    installed: nil
                )
            }
            if let name = customEntries[slug] {
                let target = EssentialLaunchURL.widgetTarget(
                    slug: slug, urlString: "", universalLink: nil, linkVerified: false
                )
                return LauncherSnapshot.Essential(
                    slug: slug, name: name, url: "", target: target?.absoluteString, installed: nil
                )
            }
            return nil
        }

        let snapshotCards = cards.map { card in
            LauncherSnapshot.Card(
                id: card.id,
                name: card.name,
                essentials: card.orderedSlugs.compactMap(resolve)
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
            // Top-level essentials stays = card 1 (stale-file compat, v1 widgets).
            essentials: snapshotCards.first?.essentials ?? [],
            intention: intention,
            focus: LauncherSnapshot.FocusState(
                activeUntil: activeSnapshot?.plannedEndAt,
                nextSchedule: next
            ),
            generatedAt: now,
            cards: snapshotCards
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
        let cards = MinusContainer.cards(in: context).map {
            CardInput(id: $0.id, name: $0.name, orderedSlugs: $0.orderedSlugs)
        }
        let customs = Dictionary(
            MinusContainer.customEntries(in: context).map { ($0.slug, $0.displayName) },
            uniquingKeysWith: { first, _ in first }
        )
        // v1.7: a hidden goal publishes as "" — the widget footer's existing
        // isEmpty branch then hides it, and the focus widget's idle state
        // falls through to the honest "begin a focus session" line.
        let config = MinusContainer.userConfig(in: context)
        let intention = config.showsIntention ? config.intentionText : ""
        let schedules = (try? context.fetch(
            FetchDescriptor<FocusSchedule>(predicate: #Predicate { $0.isEnabled })
        )) ?? []

        snapshot(
            cards: cards,
            customEntries: customs,
            intention: intention,
            activeSnapshot: coordinator.activeSnapshot,
            schedules: schedules,
            now: ClockProvider.now()
        ).write()

        WidgetCenter.shared.reloadAllTimelines()
    }
}
