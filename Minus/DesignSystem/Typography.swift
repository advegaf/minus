import CoreText
import SwiftUI

/// General Sans, two weights, fixed sizes (no Dynamic Type — the sculptural
/// stacked compositions depend on exact metrics). Token names are abstract so
/// swapping in PP Neue Montreal later is a two-line change here.
enum MFont {
    static let regular = "GeneralSans-Regular"
    static let bold = "GeneralSans-Bold"
}

/// The remapped Vivid+Co scale. Ratios preserved from the web spec
/// (display:body ≈ 7×), sizes tuned for a 393pt-wide canvas.
enum MNType {
    case display      // 96pt, lh 1.0, -0.02em — the clock, focus countdown
    case displaySm    // 64pt, lh 1.0, -0.02em
    case headingLg    // 40pt, lh 1.05, -0.01em
    case heading      // 28pt, lh 1.2, -0.01em — the ONLY weight-700 size
    case bodyXl       // 28pt, lh 1.2, -0.01em, REGULAR — widget large text
    case bodyLg       // 22pt, lh 1.2, -0.01em — launcher rows, list titles
    case body         // 17pt, lh 1.5, +0.01em
    /// 17pt BOLD. The one sanctioned exception to "700 only at .heading":
    /// a single emphasised word inside a body line (the empty card's
    /// "choose essentials"). Never a whole sentence.
    case bodyStrong
    case caption      // 13pt, lh 1.2, +0.02em — eyebrows, nav, uppercase labels

    var size: CGFloat {
        switch self {
        case .display: 96
        case .displaySm: 64
        case .headingLg: 40
        case .heading, .bodyXl: 28
        case .bodyLg: 22
        case .body, .bodyStrong: 17
        case .caption: 13
        }
    }

    var fontName: String {
        (self == .heading || self == .bodyStrong) ? MFont.bold : MFont.regular
    }

    /// Tracking in points (em fraction × size).
    var tracking: CGFloat {
        switch self {
        case .display, .displaySm: -0.02 * size
        case .headingLg, .heading, .bodyXl, .bodyLg: -0.01 * size
        case .body, .bodyStrong: 0.01 * size
        case .caption: 0.02 * size
        }
    }

    /// Target line height as a multiple of size.
    var leading: CGFloat {
        switch self {
        case .display, .displaySm: 1.0
        case .headingLg: 1.05
        case .heading, .bodyXl, .bodyLg, .caption: 1.2
        case .body, .bodyStrong: 1.5
        }
    }

    var font: Font {
        .custom(fontName, fixedSize: size)
    }

    /// The font's natural line height from CoreText metrics — used to compute
    /// the spacing corrections that produce exact target leading.
    var naturalLineHeight: CGFloat {
        let ct = CTFontCreateWithName(fontName as CFString, size, nil)
        return CTFontGetAscent(ct) + CTFontGetDescent(ct) + CTFontGetLeading(ct)
    }
}

extension View {
    /// Applies font + tracking + line spacing for a type token. Line spacing
    /// adjusts SwiftUI's extra inter-line gap toward the target leading; for
    /// the 1.0-leading display sizes use `DisplayStack` (negative spacing)
    /// instead, since lineSpacing cannot go below the natural height.
    func mnType(_ token: MNType) -> some View {
        let extra = max(0, token.size * token.leading - token.naturalLineHeight)
        return self
            .font(token.font)
            .tracking(token.tracking)
            .lineSpacing(extra)
    }
}

/// Stacked display lines at exact 1.0 leading — the sculptural headline
/// device. VStack spacing is (target − natural) line height, which is negative
/// for display sizes, pulling lines into the tight stack the brand demands.
struct DisplayStack: View {
    var lines: [String]
    var token: MNType = .display
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: token.size * token.leading - token.naturalLineHeight) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(token.font)
                    .tracking(token.tracking)
            }
        }
    }
}
