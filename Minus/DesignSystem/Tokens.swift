import SwiftUI
import UIKit

/// Vivid+Co tokens — the entire chromatic and spatial vocabulary of minus.
/// The three prism colors deliberately do NOT live here: they are fileprivate
/// to PrismArtifact.swift and must never leak into general UI (enforced by
/// DesignGuardTests).
///
/// v1.19: every color is a PAIR. The names still say obsidian and bone, but
/// they mean canvas and ink: at night the canvas is the void, in daylight it
/// is paper. Because the pair resolves inside the Color itself, all ~190 call
/// sites across the app, the widget and the report read exactly as they did.
/// The light values are derived to hold the dark palette's contrast
/// RELATIONSHIPS, not to invert its hex.
enum MN {
    // MARK: Colors

    /// Canvas: #101010 void / #F7F4EE paper. Warm rather than white, so a
    /// 96pt clock at 7am does not glare.
    static let obsidian = Color(mnDark: 0x101010, mnLight: 0xF7F4EE)
    /// The one surface that departs from the canvas: a lighter band in the
    /// dark, a darker one on paper.
    static let graphiteVeil = Color(mnDark: 0x495764, mnLight: 0xEDE9E1)
    /// Ink: every piece of text and UI chrome. 19:1 on the void, 17:1 on paper.
    static let boneWhite = Color(mnDark: 0xFFFDF9, mnLight: 0x101010)
    /// De-emphasized metadata ONLY (labels, taxonomy). Never primary content.
    /// Same hue family both ways, darkened on paper to hold about 5:1.
    static let fogBlue = Color(mnDark: 0x6F879C, mnLight: 0x55697B)
    /// 1px hairline dividers and card outlines. The only border color, and
    /// deliberately near-invisible in both appearances.
    static let ashBorder = Color(mnDark: 0x403F3F, mnLight: 0xCFCAC1)

    /// The void itself, never paper. For the one surface that must stay dark
    /// in both appearances: the prism's plinth, whose additive fringes only
    /// exist against darkness.
    static let obsidianAlways = Color(mnHex: 0x101010)

    // MARK: Shape

    enum Radius {
        /// Buttons are square by design.
        static let button: CGFloat = 0
        /// Nav elements and the outlined CTA.
        static let nav: CGFloat = 5
        /// Cards.
        static let card: CGFloat = 15
    }

    /// Hairline stroke width for ash borders and specular lines.
    static let hairline: CGFloat = 1

    // MARK: Spacing (4pt base)

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 16
        static let m: CGFloat = 20
        static let l: CGFloat = 40
        static let xl: CGFloat = 56
        static let xxl: CGFloat = 64
        /// Section rhythm (web 108 remapped for a 393pt canvas).
        static let section: CGFloat = 72
    }

    /// Minimum hit target for any interactive element.
    static let minHit: CGFloat = 44
}

extension Color {
    /// sRGB color from a 24-bit hex literal.
    init(mnHex hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// A token that resolves per trait collection. This is the whole of light
    /// mode's machinery: the pair lives inside the Color, so every call site
    /// keeps reading `MN.obsidian` and gets the right one. Resolution happens
    /// at render, so a system appearance change repaints without any state.
    init(mnDark dark: UInt32, mnLight light: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(mnHex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    /// The UIKit twin of `Color(mnHex:)`, needed because a dynamic provider
    /// must hand back UIColors.
    convenience init(mnHex hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
