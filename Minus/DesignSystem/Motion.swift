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
}

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
