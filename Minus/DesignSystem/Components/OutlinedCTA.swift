import SwiftUI

/// The single bordered control in minus. Transparent fill, one bone-white
/// hairline, square-ish 5pt corners, uppercase caption label. Press is the
/// universal 0.97 scale — never a fade, never a fill swap.
struct OutlinedCTA: View {
    let title: String
    /// Full-width variant for primary moments (sheet footers, empty states).
    var prominent: Bool = false
    let action: () -> Void

    init(title: String, prominent: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.prominent = prominent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.boneWhite)
                .padding(.vertical, 12)
                .padding(.horizontal, MN.Space.m)
                .frame(maxWidth: prominent ? .infinity : nil, minHeight: MN.minHit)
                .overlay(
                    RoundedRectangle(cornerRadius: MN.Radius.nav, style: .continuous)
                        .stroke(MN.boneWhite, lineWidth: MN.hairline)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.mnPress)
    }
}

#if DEBUG
#Preview {
    ZStack {
        MN.obsidian.ignoresSafeArea()
        VStack(spacing: MN.Space.m) {
            OutlinedCTA(title: "Begin Focus") {}
            OutlinedCTA(title: "Start Session", prominent: true) {}
        }
        .padding(MN.Space.m)
    }
    .preferredColorScheme(.dark)
}
#endif
