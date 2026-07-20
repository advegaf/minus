import SwiftUI

/// Motion vocabulary. The signature curve is the brand's "optical focus pull";
/// everything else is fast ease-out. Transform + opacity only — never animate
/// layout-driving properties.
enum MMotion {
    /// cubic-bezier(0.52, 0.01, 0, 1) at 0.5s — meaningful state changes only
    /// (focus start/stop, screen-level reveals). Not for micro-interactions.
    static let signature = Animation.timingCurve(0.52, 0.01, 0, 1, duration: 0.5)

    static func signature(_ duration: Double) -> Animation {
        .timingCurve(0.52, 0.01, 0, 1, duration: duration)
    }

    /// Strong ease-out for entrances, dropdowns, small reveals (~200ms).
    static let micro = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.2)

    /// Press feedback — instant response (160ms).
    static let press = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.16)

    /// Exits are always faster and subtler than enters.
    static let exit = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.14)

    /// Per-item stagger delay for list entrances.
    static let staggerStep: Double = 0.05
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
