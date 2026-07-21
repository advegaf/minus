import Foundation
import SwiftData
import SwiftUI

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
        }
        container = MinusContainer.make(inMemory: uiTestMode)
        #if DEBUG
        DemoSeed.seedFromEnvironment(context: container.mainContext)
        #endif
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
}
