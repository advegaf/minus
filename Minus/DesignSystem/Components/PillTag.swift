import SwiftUI

/// A capsule of metadata — taxonomy, counts, session length. Fog-blue caption
/// text inside a single ash hairline; it is information, never an action, so it
/// carries no press feedback and never uses bone-white.
struct PillTag: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .mnType(.caption)
            .foregroundStyle(MN.fogBlue)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .overlay(
                Capsule()
                    .stroke(MN.ashBorder, lineWidth: MN.hairline)
            )
    }
}

#if DEBUG
#Preview {
    ZStack {
        MN.obsidian.ignoresSafeArea()
        HStack(spacing: MN.Space.xs) {
            PillTag("24 min")
            PillTag("Streak 14")
            PillTag("Awareness")
        }
    }
    .preferredColorScheme(.dark)
}
#endif
