import SwiftUI

/// A content container defined by a single ash hairline and 15pt corners.
/// There is no shadow anywhere in minus — a card reads as raised only through
/// the contrast of its surface against the obsidian void.
struct HairlineCard<Content: View>: View {
    /// The card fill. Obsidian is the default; graphite veil is the one lighter
    /// surface, used for content bands that must separate from the canvas.
    enum Surface {
        case obsidian
        case graphiteVeil

        var color: Color {
            switch self {
            case .obsidian: MN.obsidian
            case .graphiteVeil: MN.graphiteVeil
            }
        }
    }

    var surface: Surface = .obsidian
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(MN.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: MN.Radius.card, style: .continuous)
                    .fill(surface.color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MN.Radius.card, style: .continuous)
                    .stroke(MN.ashBorder, lineWidth: MN.hairline)
            )
    }
}

#if DEBUG
#Preview {
    ZStack {
        MN.obsidian.ignoresSafeArea()
        VStack(spacing: MN.Space.m) {
            HairlineCard {
                Text("Obsidian surface")
                    .mnType(.body)
                    .foregroundStyle(MN.boneWhite)
            }
            HairlineCard(surface: .graphiteVeil) {
                Text("Graphite veil surface")
                    .mnType(.body)
                    .foregroundStyle(MN.boneWhite)
            }
        }
        .padding(MN.Space.m)
    }
    .preferredColorScheme(.dark)
}
#endif
