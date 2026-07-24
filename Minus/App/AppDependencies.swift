import Foundation
import SwiftData
import SwiftUI
import UIKit

/// Composition root: one instance owns the model container, the Screen Time
/// service, and the session coordinator for the whole app. Injected via
/// `.environment(...)`.
@MainActor
@Observable
final class AppDependencies {
    let container: ModelContainer
    let service: any ScreenTimeService
    let coordinator: SessionCoordinator

    /// A widget deep link waiting for the scene to become active — recorded by
    /// onOpenURL, consumed by MinusApp (essentials) / AppRootView (focus).
    var pendingDeepLink: DeepLink?

    var context: ModelContext { container.mainContext }

    init() {
        let uiTestMode = ProcessInfo.processInfo.arguments.contains("-UITestMode")
        ClockProvider.configureFromEnvironment()
        if uiTestMode {
            // Full isolation per test launch: fresh in-memory store, clean
            // shared state regardless of what a previous run left behind.
            SharedState.reset()
            // The iOS 27 beta simulator renders in software; UIKit animation
            // (keyboard bring-up especially — it runs on THIS process's main
            // thread) starves the run loop past XCUITest's 30s limit. Motion
            // is out of scope for automation anyway (Phase 0 finding).
            UIView.setAnimationsEnabled(false)
        }
        container = MinusContainer.make(inMemory: uiTestMode)
        #if DEBUG
        DemoSeed.seedFromEnvironment(context: container.mainContext)
        #endif
        // T1 migration: stored launcher rows carry their scheme from insert
        // time; keep them in lockstep with the catalog (sms:→messages: etc.)
        // so pre-1.2 installs stop landing in compose sheets.
        for row in (try? container.mainContext.fetch(FetchDescriptor<EssentialApp>())) ?? [] {
            if let catalog = EssentialAppCatalog.app(slug: row.slug), row.urlScheme != catalog.urlString {
                row.urlScheme = catalog.urlString
            }
        }
        Self.migrateToCards(context: container.mainContext)

        service = ScreenTimeServiceFactory.make()
        coordinator = SessionCoordinator(service: service, context: container.mainContext)
        // Widgets track every coordinator mutation through the bridge.
        // (Capture the context, not self — no retain cycle through the closure.)
        let mainContext = container.mainContext
        coordinator.onStateChange = { [weak coordinator] in
            guard let coordinator else { return }
            LauncherBridge.publish(context: mainContext, coordinator: coordinator)
        }
        coordinator.reconcile()
    }

    /// v1.6 fold: pre-cards installs carry catalog EssentialApp rows; exactly
    /// once, they become card "one" and those rows are deleted (EssentialApp
    /// keeps only "custom-" registry entries from here on). Idempotent — any
    /// existing card means the fold already ran.
    static func migrateToCards(context: ModelContext) {
        let cardCount = (try? context.fetchCount(FetchDescriptor<LauncherCard>())) ?? 0
        guard cardCount == 0 else { return }
        let rows = (try? context.fetch(
            FetchDescriptor<EssentialApp>(sortBy: [SortDescriptor(\.sortOrder)])
        )) ?? []
        let catalogRows = rows.filter { !CustomSlug.isCustom($0.slug) && EssentialAppCatalog.app(slug: $0.slug) != nil }
        guard !catalogRows.isEmpty else { return }
        let slugs = catalogRows.map(\.slug)
        context.insert(
            LauncherCard(
                name: "one",
                orderedSlugs: Array(slugs.prefix(EssentialAppCatalog.homeCap)),
                sortOrder: 0
            )
        )
        for row in catalogRows { context.delete(row) }
        try? context.save()
    }
}
