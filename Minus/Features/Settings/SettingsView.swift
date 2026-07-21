import SwiftUI

// Placeholder — replaced in Phase 2f.
struct SettingsView: View {
    var body: some View {
        ZStack {
            MN.obsidian.ignoresSafeArea()
            Text("SETTINGS")
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.fogBlue)
        }
    }
}
