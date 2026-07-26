import UIKit
import XCTest
@testable import Minus

/// Enforces that the design system's bundled type family actually resolves
/// at runtime. GeneralSans-Regular and GeneralSans-Bold are registered via
/// the `UIAppFonts` key in Support/Info.plist (see project.yml); this test
/// class hosts in the Minus app (default XcodeGen unit-test setup with a
/// dependency on the Minus target) so that registration has already
/// happened by the time these run.
///
/// A failure here almost always means the PostScript name baked into
/// Minus/DesignSystem/Typography.swift (`MFont.regular` / `MFont.bold`) no
/// longer matches the name actually embedded in the .otf file. The
/// diagnostic dump below lists every font UIKit sees so that mismatch is
/// diagnosable from the test log alone, without inspecting the .otf files.
final class FontRegistrationTests: XCTestCase {
    private static let regularPostScriptName = "GeneralSans-Regular"
    private static let boldPostScriptName = "GeneralSans-Bold"
    private static let testSize: CGFloat = 17

    func testGeneralSansRegularIsRegistered() {
        XCTAssertNotNil(
            UIFont(name: Self.regularPostScriptName, size: Self.testSize),
            Self.diagnosticMessage(missing: Self.regularPostScriptName)
        )
    }

    func testGeneralSansBoldIsRegistered() {
        XCTAssertNotNil(
            UIFont(name: Self.boldPostScriptName, size: Self.testSize),
            Self.diagnosticMessage(missing: Self.boldPostScriptName)
        )
    }

    /// Every approved face, both weights. A face the picker offers but the
    /// bundle lacks would fall back to the SYSTEM font at runtime, which no
    /// source rule can see — so the suite is where it gets caught.
    func testEveryApprovedTypefaceIsRegistered() {
        for face in MTypeface.allCases {
            XCTAssertNotNil(
                UIFont(name: face.regular, size: Self.testSize),
                Self.diagnosticMessage(missing: face.regular)
            )
            XCTAssertNotNil(
                UIFont(name: face.bold, size: Self.testSize),
                Self.diagnosticMessage(missing: face.bold)
            )
        }
    }

    /// The approved list, pinned. Adding a sixth face has to be a deliberate
    /// act that edits this test, not a quiet import.
    func testTheApprovedListIsExactlyTheseFive() {
        XCTAssertEqual(
            Set(MTypeface.allCases.map(\.rawValue)),
            ["generalSans", "satoshi", "switzer", "cabinetGrotesk", "chillax"]
        )
    }

    /// Every approved face is offerable, so the picker never shrinks silently.
    func testEveryApprovedTypefaceIsOfferable() {
        XCTAssertEqual(MTypeface.registered.count, MTypeface.allCases.count)
    }

    func testUnknownAndUnregisteredNamesResolveToTheFallback() {
        XCTAssertEqual(MTypeface.resolve(nil), .generalSans)
        XCTAssertEqual(MTypeface.resolve("bogus"), .generalSans)
        XCTAssertEqual(MTypeface.resolve("satoshi"), .satoshi)
    }

    /// Dumps every registered font family and its PostScript names, so a
    /// PostScript-name mismatch is diagnosable from the test log alone.
    private static func diagnosticMessage(missing name: String) -> String {
        var lines = [
            "UIFont(name: \"\(name)\", size: \(testSize)) returned nil — font not registered or PostScript name mismatch.",
            "UIFont.familyNames + fontNames(forFamilyName:) as seen by this process:",
        ]
        for family in UIFont.familyNames.sorted() {
            let members = UIFont.fontNames(forFamilyName: family).sorted()
            lines.append("  \(family): \(members)")
        }
        return lines.joined(separator: "\n")
    }
}
