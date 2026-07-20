import SwiftUI

/// Vivid+Co tokens — the entire chromatic and spatial vocabulary of minus.
/// The three prism colors deliberately do NOT live here: they are fileprivate
/// to PrismArtifact.swift and must never leak into general UI (enforced by
/// DesignGuardTests).
enum MN {
    // MARK: Colors

    /// #101010 — page canvas, the void every screen sits in.
    static let obsidian = Color(mnHex: 0x101010)
    /// #495764 — the one lighter surface; content bands, never full screens.
    static let graphiteVeil = Color(mnHex: 0x495764)
    /// #FFFDF9 — every piece of text and UI chrome.
    static let boneWhite = Color(mnHex: 0xFFFDF9)
    /// #6F879C — de-emphasized metadata ONLY (labels, taxonomy). Never primary content.
    static let fogBlue = Color(mnHex: 0x6F879C)
    /// #403F3F — 1px hairline dividers and card outlines. The only border color.
    static let ashBorder = Color(mnHex: 0x403F3F)

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
}
