import SwiftUI

/// A run of characters where every digit occupies a fixed slot and a colon a
/// half slot, so the line's width is constant no matter the values. Internal —
/// shared by the clock monument and the focus countdown. The slot is derived
/// from the token and the environment's typeface, so a face change re-carves
/// it rather than drawing new glyphs in the old face's slots.
struct FixedDigits: View {
    let text: String
    var token: MNType = .display
    var color: Color = MN.boneWhite
    @Environment(\.mnTypeface) private var face
    /// How each glyph sits in its slot. The clock monument uses `.leading` so
    /// its first digit's edge always meets the page margin (a centered narrow
    /// "1" would otherwise shove the whole monument right); inline runs like the
    /// countdown keep the balanced default.
    var alignment: Alignment = .center

    var body: some View {
        let slot = DigitMetrics.slot(token, face: face)
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                Text(String(character))
                    .font(token.font(face))
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
    @Environment(\.mnTypeface) private var face

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let now = ClockProvider.now()
            let hour = Self.field(Calendar.current.component(.hour, from: now))
            let minute = Self.field(Calendar.current.component(.minute, from: now))

            VStack(alignment: .leading, spacing: DigitMetrics.displayLineSpacing(face: face)) {
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
