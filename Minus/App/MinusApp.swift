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
                // Publish once per launch, not only on a phase CHANGE. A
                // first launch (or one whose scene never transitions, e.g.
                // opened while the phone is locked) otherwise leaves the app
                // group with no snapshot at all, and the widget has nothing
                // to render but its setup invitation.
                .task {
                    LauncherBridge.publish(context: deps.context, coordinator: deps.coordinator)
                }
        }
    }

    /// The trampoline: a widget cell that cannot open its target itself
    /// bounces here, and minus walks the whole launch plan on its behalf
    /// (universal link, scheme, the user's shortcut). The veil stays up until
    /// the open resolves, so Home never mounts mid-bounce.
    /// (.focus is consumed by AppRootView, which owns the router.)
    private func consumeEssentialLink() {
        guard case .openEssential(let slug) = deps.pendingDeepLink else { return }
        // The bounce carries a slug and nothing else, so the identity for an
        // added app has to be looked up here. Without it the widget path lands
        // on the Shortcuts route exactly as Home used to.
        let customs = Dictionary(
            MinusContainer.customEntries(in: deps.context)
                .map { ($0.slug, CustomEntry(name: $0.displayName, bundleID: $0.bundleID)) },
            uniquingKeysWith: { first, _ in first }
        )
        let identity = EssentialLauncher.bundleID(for: slug, customs: customs)
        Task {
            await EssentialLauncher.open(slug: slug, bundleID: identity)
            deps.pendingDeepLink = nil
        }
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
