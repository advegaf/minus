import SwiftUI

@main
struct MinusApp: App {
    var body: some Scene {
        WindowGroup {
            rootView
                .preferredColorScheme(.dark)
        }
    }

    /// The obsidian void every screen sits in. In DEBUG, `MINUS_SCREEN=gallery`
    /// swaps in the design-system proof sheet instead.
    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if ProcessInfo.processInfo.environment["MINUS_SCREEN"] == "gallery" {
            DesignGallery()
        } else {
            ZStack { MN.obsidian.ignoresSafeArea() }
        }
        #else
        ZStack { MN.obsidian.ignoresSafeArea() }
        #endif
    }
}
