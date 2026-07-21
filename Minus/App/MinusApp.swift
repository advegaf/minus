import SwiftData
import SwiftUI

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
                .onChange(of: scenePhase) { _, phase in
                    // Every foreground drains the monitor's ledger and sweeps
                    // stale sessions — trust invariant #3.
                    if phase == .active {
                        deps.coordinator.reconcile()
                    }
                }
        }
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
