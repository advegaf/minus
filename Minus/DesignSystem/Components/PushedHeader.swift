import SwiftUI

/// Minimal back affordance for pushed screens with hidden system chrome: a
/// bone-white arrow glyph, 44pt target.
struct BackGlyph: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Text("\u{2190}")
                .mnType(.bodyLg)
                .foregroundStyle(MN.boneWhite)
                .frame(width: MN.minHit, height: MN.minHit)
                .contentShape(Rectangle())
        }
        .buttonStyle(.mnPress)
        .accessibilityIdentifier("nav-back")
    }
}

/// The one header for pushed screens: glyph and eyebrow on a single optical
/// line (G2) — HStack centering does the alignment, no overlay hacks. Sits
/// inside the screen's horizontal margin; the glyph's 44pt frame provides its
/// own breathing room.
struct PushedHeader: View {
    let eyebrow: String

    var body: some View {
        HStack(spacing: MN.Space.xs) {
            BackGlyph()
            Text(eyebrow)
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.fogBlue)
            Spacer(minLength: 0)
        }
        .padding(.top, MN.Space.xxs)
    }
}
