import SwiftUI

// Placeholder — replaced in Phase 2d.
struct FocusView: View {
    var body: some View {
        ZStack {
            MN.obsidian.ignoresSafeArea()
            Text("FOCUS")
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.fogBlue)
        }
    }
}
