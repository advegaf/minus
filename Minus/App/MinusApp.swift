import SwiftData
import SwiftUI
import UIKit

@main
struct MinusApp: App {
    @State private var deps = AppDependencies()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            rootView
                .preferredColorScheme(.dark)
                .environment(deps)
                .modelContainer(deps.container)
                // Cold-start race: UIApplication.open is silently dropped
                // before the scene is active, so onOpenURL only RECORDS the
                // link; consumption waits for .active.
                .onOpenURL { url in
                    deps.pendingDeepLink = DeepLink.parse(url)
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        // Every foreground drains the monitor's ledger and
                        // sweeps stale sessions — trust invariant #3.
                        deps.coordinator.reconcile()
                        consumeEssentialLink()
                        LauncherBridge.publish(context: deps.context, coordinator: deps.coordinator)
                    case .background:
                        // A widget is only ever seen after we leave foreground —
                        // this single publish catches every UI-driven edit.
                        LauncherBridge.publish(context: deps.context, coordinator: deps.coordinator)
                    default:
                        break
                    }
                }
                .onChange(of: deps.pendingDeepLink) { _, _ in
                    // Warm path: the phase is already active and won't change.
                    if scenePhase == .active {
                        consumeEssentialLink()
                    }
                }
        }
    }

    /// The trampoline: minus://open/{slug} → the essential's own scheme.
    /// (.focus is consumed by AppRootView, which owns the router.)
    private func consumeEssentialLink() {
        guard case .openEssential(let slug) = deps.pendingDeepLink else { return }
        deps.pendingDeepLink = nil
        guard let url = EssentialAppCatalog.app(slug: slug)?.url else { return }
        UIApplication.shared.open(url)
    }

    /// In DEBUG, `MINUS_SCREEN=gallery` swaps in the design-system proof sheet.
    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if ProcessInfo.processInfo.environment["MINUS_SCREEN"] == "gallery" {
            DesignGallery()
        } else {
            AppRootView()
        }
        #else
        AppRootView()
        #endif
    }
}
