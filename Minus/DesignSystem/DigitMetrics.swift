import CoreText
import SwiftUI

/// Widest-digit advances, computed from the font's own metrics so every
/// numeric slot in the app (the clock monument, the focus countdown) locks to
/// a fixed width and never reflows as values tick. CoreText, not layout, is
/// the source of truth — deterministic regardless of which glyphs are shown.
///
/// Every measurement is per typeface. A slot measured against one face and
/// drawn in another is exactly how a 96pt monument ends up mis-tracked or
/// clipped, so nothing here is a plain `static let` any more.
@MainActor
enum DigitMetrics {
    private struct Key: Hashable {
        let face: MTypeface
        let size: CGFloat
    }

    private static var slots: [Key: CGFloat] = [:]
    private static var lineSpacings: [MTypeface: CGFloat] = [:]

    /// The widest advance among "0"–"9" at `size` for `fontName`, via CoreText.
    static func slotWidth(fontName: String, size: CGFloat) -> CGFloat {
        let font = CTFontCreateWithName(fontName as CFString, size, nil)
        let scalars = Array("0123456789".utf16)
        var glyphs = [CGGlyph](repeating: 0, count: scalars.count)
        guard CTFontGetGlyphsForCharacters(font, scalars, &glyphs, scalars.count) else {
            return size * 0.6
        }
        var advances = [CGSize](repeating: .zero, count: glyphs.count)
        CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)
        return advances.map(\.width).max() ?? size * 0.6
    }

    /// The digit slot for a token in a face. Measured once per pair, then
    /// cached — a typeface change measures its own and keeps both.
    static func slot(_ token: MNType, face: MTypeface) -> CGFloat {
        let key = Key(face: face, size: token.size)
        if let cached = slots[key] { return cached }
        let width = slotWidth(fontName: token.fontName(face), size: token.size)
        slots[key] = width
        return width
    }

    /// The negative inter-line gap that pulls display lines into a 1.0-leading
    /// stack (the DisplayStack device, for the clock).
    static func displayLineSpacing(face: MTypeface) -> CGFloat {
        if let cached = lineSpacings[face] { return cached }
        let spacing = MNType.display.size * MNType.display.leading
            - MNType.display.naturalLineHeight(face)
        lineSpacings[face] = spacing
        return spacing
    }
}
