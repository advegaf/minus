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
        coordinator.reconcile()
    }
}
