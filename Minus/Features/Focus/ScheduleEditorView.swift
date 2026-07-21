import SwiftUI

// Placeholder — replaced in Phase 2d.
struct ScheduleEditorView: View {
    var scheduleID: UUID?

    var body: some View {
        ZStack {
            MN.obsidian.ignoresSafeArea()
            Text("EDITOR")
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.fogBlue)
        }
    }
}
