import CoreText
import SwiftUI

/// Widest-digit advances, computed once from the font's own metrics so every
/// numeric slot in the app (the clock monument, the focus countdown) locks to a
/// fixed width and never reflows as values tick. CoreText, not layout, is the
/// source of truth — deterministic regardless of which glyphs are on screen.
enum DigitMetrics {
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

    /// The 96pt clock slot — cached; computed exactly once.
    static let displaySlot = slotWidth(fontName: MFont.regular, size: MNType.display.size)
    /// The 64pt slot — the focus countdown monument.
    static let displaySmSlot = slotWidth(fontName: MFont.regular, size: MNType.displaySm.size)
    /// The 13pt caption slot — cached; reused by the home focus state line.
    static let captionSlot = slotWidth(fontName: MFont.regular, size: MNType.caption.size)

    /// The negative inter-line gap that pulls display lines into a 1.0-leading
    /// stack (the DisplayStack device, precomputed for the clock).
    static let displayLineSpacing =
        MNType.display.size * MNType.display.leading - MNType.display.naturalLineHeight
}

/// A run of characters where every digit occupies a fixed slot and a colon a
/// half slot, so the line's width is constant no matter the values. Internal —
/// shared by the clock monument and the focus countdown.
struct FixedDigits: View {
    let text: String
    var token: MNType = .display
    var slot: CGFloat = DigitMetrics.displaySlot
    var color: Color = MN.boneWhite
    /// How each glyph sits in its slot. The clock monument uses `.leading` so
    /// its first digit's edge always meets the page margin (a centered narrow
    /// "1" would otherwise shove the whole monument right); inline runs like the
    /// countdown keep the balanced default.
    var alignment: Alignment = .center

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                Text(String(character))
                    .font(token.font)
                    .foregroundStyle(color)
                    .frame(width: character == ":" ? slot * 0.5 : slot, alignment: alignment)
            }
        }
    }
}

/// The monument: a giant stacked 24-hour clock, hour line over minute line, at
/// 1.0 leading. Time is ALWAYS read from `ClockProvider.now()` inside a
/// per-second timeline so a real clock flips its minute and a frozen clock
/// stands perfectly still — both correct. The minute line flips on change; the
/// hour line only flips at the top of the hour.
struct ClockDisplay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let now = ClockProvider.now()
            let hour = Self.field(Calendar.current.component(.hour, from: now))
            let minute = Self.field(Calendar.current.component(.minute, from: now))

            VStack(alignment: .leading, spacing: DigitMetrics.displayLineSpacing) {
                flippingLine(hour)
                flippingLine(minute)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("clock-display")
        }
    }

    /// One clock line whose identity is its own string, so it re-enters (and so
    /// animates) only when *that* line's value changes. The per-digit slots are
    /// collapsed to a single static-text representation ("09") for assistive
    /// tech and UI tests.
    private func flippingLine(_ value: String) -> some View {
        ZStack(alignment: .leading) {
            FixedDigits(text: value, alignment: .leading)
                .id(value)
                .transition(lineTransition)
        }
        .animation(reduceMotion ? MMotion.settle(MMotion.exit, reduceMotion: true) : MMotion.micro, value: value)
        .accessibilityRepresentation { Text(value) }
    }

    /// Enter from below, exit upward — enters are the slower micro curve, exits
    /// the faster exit curve, per the brand's asymmetry. Reduce-motion collapses
    /// both to a plain crossfade.
    private var lineTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 8)).animation(MMotion.micro),
            removal: .opacity.combined(with: .offset(y: -8)).animation(MMotion.exit)
        )
    }

    /// Zero-padded two-digit field — deterministic and sculptural regardless of
    /// locale (no DateFormatter, which would localize digits and separators).
    private static func field(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

#if DEBUG
#Preview {
    ZStack {
        MN.obsidian.ignoresSafeArea()
        ClockDisplay()
            .padding(MN.Space.m)
    }
    .preferredColorScheme(.dark)
}
#endif
