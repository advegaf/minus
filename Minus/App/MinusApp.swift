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
                        // Bounce FIRST (T2 — the trampoline must be a blink),
                        // then the ledger drain and sweep (trust invariant #3).
                        consumeEssentialLink()
                        deps.coordinator.reconcile()
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

    /// The trampoline: minus://open/{slug} → wherever the resolver points
    /// (catalog scheme, or the shortcuts route for comm + custom slugs).
    /// (.focus is consumed by AppRootView, which owns the router.)
    private func consumeEssentialLink() {
        guard case .openEssential(let slug) = deps.pendingDeepLink else { return }
        deps.pendingDeepLink = nil
        let urlString = EssentialAppCatalog.app(slug: slug)?.urlString ?? ""
        guard !urlString.isEmpty || CustomSlug.isCustom(slug),
              let url = EssentialLaunchURL.resolve(slug: slug, urlString: urlString) else { return }
        UIApplication.shared.open(url)
    }

    /// In DEBUG, `MINUS_SCREEN=gallery` swaps in the design-system proof sheet.
    /// During an essential-app trampoline the root is a bare obsidian veil —
    /// no clock, no launcher — so the bounce reads as a black blink, not a
    /// visit to minus (T2).
    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if ProcessInfo.processInfo.environment["MINUS_SCREEN"] == "gallery" {
            DesignGallery()
        } else {
            veiledRoot
        }
        #else
        veiledRoot
        #endif
    }

    @ViewBuilder
    private var veiledRoot: some View {
        if case .openEssential = deps.pendingDeepLink {
            MN.obsidian.ignoresSafeArea()
        } else {
            AppRootView()
        }
    }
}
