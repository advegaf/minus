import SwiftUI

/// Motion vocabulary — v1.7: every token is a critically-damped spring
/// (`.smooth`, bounce 0). Springs are interruptible and retargetable (velocity
/// carries when a value changes mid-flight; timing curves restart), and they
/// arrive asymptotically — no terminal whip, which is what read as "snappy"
/// in the old cubic-bezier set. Stillness kept: zero bounce everywhere.
/// Transform + opacity only — never animate layout-driving properties.
enum MMotion {
    /// Meaningful state changes only (focus start/stop, screen-level reveals).
    /// Not for micro-interactions.
    static let signature = Animation.smooth(duration: 0.5)

    static func signature(_ duration: Double) -> Animation {
        .smooth(duration: duration)
    }

    /// Entrances, dropdowns, small reveals — calm but under a third of a second.
    static let micro = Animation.smooth(duration: 0.3)

    /// Press feedback — springs respond with immediate velocity, so this still
    /// feels instant while settling gently.
    static let press = Animation.smooth(duration: 0.2)

    /// Exits are always faster and subtler than enters.
    static let exit = Animation.smooth(duration: 0.18)

    /// Per-item stagger delay for list entrances.
    static let staggerStep: Double = 0.04

    /// The reduce-motion substitute for any token: same timing, no spring,
    /// no travel. One helper so every list, clock, and step agrees instead of
    /// each inventing its own easeInOut.
    static func settle(_ token: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : token
    }
}

// MARK: - The vocabulary, in one place
//
// signature (0.5s)  screen-level state: focus starts or ends, onboarding
//                   gives way to Home, a card page slides under a tab tap.
// micro (0.3s)      entrances and small reveals: launcher rows, captions
//                   appearing, a field's hairline waking up.
// press (0.2s)      the universal 0.97 push-back on every tappable.
// exit (0.18s)      anything leaving. Always faster than its entrance.
// stagger (0.04s)   per-row delay, first paint only, never on a re-render.
//
// Deliberately NOT ours:
// - Navigation pushes and pops are the system's. The restored edge-swipe
//   mirrors that curve exactly, so overriding it would desync the gesture
//   from the animation it drives.
// - Programmatic jumps (a widget deep link) carry no animation at all: you
//   asked for a screen, not for a journey to it.
// - The hold-to-end gauge is a deliberate 2s linear fill. Slow where the
//   decision is, fast where the release is.

/// Universal press feedback: scale 0.97, no opacity games. Applied by every
/// tappable in the app (buttons, rows, pills).
struct MNPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(MMotion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == MNPressStyle {
    static var mnPress: MNPressStyle { MNPressStyle() }
}
