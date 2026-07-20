import SwiftUI

/// The app's navigation is pure typography: uppercase caption labels with no
/// underline, border, or background, separated by generous space. Ghost text
/// that only reveals itself as tappable through the 0.97 press.
struct NavTextRow: View {
    /// An item is its uppercase label and the action it fires.
    typealias Item = (title: String, action: () -> Void)

    let items: [Item]
    /// Space between labels — generous by default so the row reads as a menu,
    /// not a sentence.
    var spacing: CGFloat = MN.Space.l

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Button(action: item.action) {
                    Text(item.title)
                        .mnType(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(MN.boneWhite)
                        .frame(minWidth: MN.minHit, minHeight: MN.minHit)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.mnPress)
                .accessibilityIdentifier("nav-\(item.title.lowercased())")
            }
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        MN.obsidian.ignoresSafeArea()
        NavTextRow(items: [
            ("Focus", {}),
            ("Awareness", {}),
            ("Settings", {}),
        ])
    }
    .preferredColorScheme(.dark)
}
#endif
