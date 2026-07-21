import SwiftUI

// Placeholder — replaced in Phase 2e.
struct AwarenessView: View {
    var body: some View {
        ZStack {
            MN.obsidian.ignoresSafeArea()
            Text("AWARENESS")
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.fogBlue)
        }
    }
}
