import SwiftUI
import UIKit
import XCTest
@testable import Minus

/// minus follows the phone: the void at night, paper in daylight. Every token
/// is a pair, and the pair resolves inside the Color itself — which is what
/// lets ~190 call sites stay untouched. These tests pin that mechanism: if a
/// token ever reverts to a literal, both appearances would silently agree and
/// light mode would quietly die.
final class AppearanceTests: XCTestCase {
    private let light = UITraitCollection(userInterfaceStyle: .light)
    private let dark = UITraitCollection(userInterfaceStyle: .dark)

    private func resolved(_ color: Color, _ traits: UITraitCollection) -> UIColor {
        UIColor(color).resolvedColor(with: traits)
    }

    /// Compare components, never UIColor identity: a statically-built color
    /// and a dynamically-resolved one carry different internal
    /// representations even when they are the same color on screen.
    private func rgb(_ color: UIColor) -> [CGFloat] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a].map { ($0 * 255).rounded() }
    }

    private func assertDiffers(_ color: Color, _ name: String) {
        XCTAssertNotEqual(
            rgb(resolved(color, light)), rgb(resolved(color, dark)),
            "\(name) resolves the same in both appearances — it is no longer a pair."
        )
    }

    func testEveryCanvasTokenCarriesBothAppearances() {
        assertDiffers(MN.obsidian, "obsidian")
        assertDiffers(MN.boneWhite, "boneWhite")
        assertDiffers(MN.fogBlue, "fogBlue")
        assertDiffers(MN.ashBorder, "ashBorder")
        assertDiffers(MN.graphiteVeil, "graphiteVeil")
        assertDiffers(MN.widgetGround, "widgetGround")
    }

    /// The canvas and the ink trade places rather than drifting apart.
    func testCanvasAndInkInvertBetweenAppearances() {
        XCTAssertEqual(rgb(resolved(MN.obsidian, dark)),
                       rgb(resolved(MN.boneWhite, light)),
                       "the dark canvas and the light ink should be the same color")
    }

    /// The prism's plinth is the one surface that must NOT follow, because
    /// every fringe it holds is additive and only exists against darkness.
    func testThePrismPlinthStaysDarkInBothAppearances() {
        XCTAssertEqual(rgb(resolved(MN.obsidianAlways, light)), rgb(resolved(MN.obsidianAlways, dark)))
        XCTAssertEqual(rgb(resolved(MN.obsidianAlways, light)), rgb(resolved(MN.obsidian, dark)))
    }

    /// Ink on paper and bone on the void both need to carry a monument.
    func testPrimaryTextClearsSevenToOneInBothAppearances() {
        for traits in [light, dark] {
            let ratio = Self.contrast(
                resolved(MN.boneWhite, traits), on: resolved(MN.obsidian, traits)
            )
            XCTAssertGreaterThan(ratio, 7, "primary text is only \(ratio):1 in \(traits.userInterfaceStyle == .dark ? "dark" : "light")")
        }
    }

    /// Secondary metadata still has to be readable, not decorative.
    func testSecondaryTextClearsFourAndAHalfInBothAppearances() {
        for traits in [light, dark] {
            let ratio = Self.contrast(
                resolved(MN.fogBlue, traits), on: resolved(MN.obsidian, traits)
            )
            XCTAssertGreaterThan(ratio, 4.5, "secondary text is only \(ratio):1 in \(traits.userInterfaceStyle == .dark ? "dark" : "light")")
        }
    }

    // MARK: WCAG relative luminance

    private static func contrast(_ a: UIColor, on b: UIColor) -> Double {
        let (l1, l2) = (luminance(a), luminance(b))
        let (hi, lo) = l1 > l2 ? (l1, l2) : (l2, l1)
        return (hi + 0.05) / (lo + 0.05)
    }

    private static func luminance(_ color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
}
