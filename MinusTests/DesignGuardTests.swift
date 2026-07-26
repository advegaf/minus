import Foundation
import XCTest

/// Source-scanning tests that permanently enforce the design system's hard
/// rules across every file under `Minus/` — the app target's own source
/// directory only (MinusMonitor, MinusReport, and MinusTests are never
/// scanned). These are deliberately dumb substring scans over raw file
/// text — no SwiftSyntax, no build step — so a violation is caught even in
/// a file that doesn't currently compile.
final class DesignGuardTests: XCTestCase {

    // MARK: - Roots

    /// This file lives at `<repoRoot>/MinusTests/DesignGuardTests.swift`, so
    /// the repo root is two `deletingLastPathComponent()` hops up.
    private static let repoRootPath: String = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // MinusTests/
            .deletingLastPathComponent() // repo root
            .path
    }()

    /// The app target's source directory — the only tree these rules scan.
    private static let appSourceRootPath: String = repoRootPath + "/Minus"

    /// Trailing-slash prefixes used for containment checks, so a sibling
    /// directory that merely starts with the same characters (e.g. a
    /// hypothetical `DesignSystemExtras/`) can never match by accident.
    private static let designSystemRootPrefix: String = appSourceRootPath + "/DesignSystem/"
    private static let prismRootPrefix: String = appSourceRootPath + "/DesignSystem/Prism/"

    // MARK: - Rule 1 — zero shadows

    func testShadowsAreBannedEverywhereUnderMinus() {
        let found = Self.findViolations(
            in: Self.swiftFiles(),
            patterns: [".shadow("]
        )
        guard !found.isEmpty else { return }
        XCTFail(Self.report(
            rule: "Rule 1 (zero shadows): `.shadow(` must not appear anywhere under Minus/. No exceptions.",
            violations: found
        ))
    }

    // MARK: - Rule 2 — prism containment

    func testPrismHexCodesAreContainedToPrismDirectory() {
        let found = Self.findViolations(
            in: Self.swiftFiles(),
            patterns: [
                "FF2A2A", "2A7FFF", "2AFF2A",
                // The paper-ground triad is contained the same way.
                "C81E1E", "1E5AC8", "1E8C3C",
            ],
            caseInsensitive: true,
            isExempt: { $0.path.hasPrefix(Self.prismRootPrefix) }
        )
        guard !found.isEmpty else { return }
        XCTFail(Self.report(
            rule: "Rule 2 (prism containment): FF2A2A / 2A7FFF / 2AFF2A (any case) may appear only under Minus/DesignSystem/Prism/.",
            violations: found
        ))
    }

    // MARK: - Rule 3 — no system fonts

    func testSystemFontsAreBannedEverywhereUnderMinus() {
        let found = Self.findViolations(
            in: Self.swiftFiles(),
            patterns: [".font(.system"]
        )
        guard !found.isEmpty else { return }
        XCTFail(Self.report(
            rule: "Rule 3 (no system fonts): `.font(.system` must not appear anywhere under Minus/ — all type must go through .mnType.",
            violations: found
        ))
    }

    // MARK: - Rule 4 — raw color containment

    func testRawColorConstructionIsContainedToDesignSystemDirectory() {
        let found = Self.findViolations(
            in: Self.swiftFiles(),
            // v1.19: the light-mode forms too. A dynamic provider, a bridged
            // UIColor or a named asset would each have walked straight past
            // the original three patterns — the one mechanism the guard could
            // not see was the one light mode is built from.
            patterns: [
                "Color(red:", "Color(mnHex:", "UIColor(red:",
                "Color(mnDark:", "UIColor(mnHex:", "Color(uiColor:",
                "UIColor {", "UIColor(dynamicProvider:",
            ],
            isExempt: { $0.path.hasPrefix(Self.designSystemRootPrefix) }
        )
        guard !found.isEmpty else { return }
        XCTFail(Self.report(
            rule: "Rule 4 (raw color containment): raw and dynamic color construction may appear only under Minus/DesignSystem/ — everything else reads an MN token.",
            violations: found
        ))
    }

    // MARK: - Rule 5b — nothing probes for installed apps

    /// v1.8: `canOpenURL` reported false on iOS 27 for installed apps whose
    /// schemes WERE declared, and the launcher turned that into a disabled
    /// row. minus opens and reports honestly instead of asking first.
    func testCanOpenURLIsBannedEverywhereUnderMinus() {
        let found = Self.findViolations(
            in: Self.swiftFiles(),
            patterns: ["canOpenURL"]
        )
        guard !found.isEmpty else { return }
        XCTFail(Self.report(
            rule: "Rule 5b (nothing probes): `canOpenURL` must not appear under Minus/. Open the URL and handle the failure (see EssentialLauncher).",
            violations: found
        ))
    }

    // MARK: - Rule 6 — no dashes in copy

    /// Em and en dashes are banned from user-facing text. Comments are
    /// dev-facing and exempt, so this rule scans string literals only.
    func testDashesAreBannedInStringLiteralsUnderMinus() {
        var violations: [Violation] = []
        for url in Self.swiftFiles().sorted(by: { $0.path < $1.path }) {
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }
            var lines: [Int] = []
            for (index, line) in contents.components(separatedBy: .newlines).enumerated() {
                let literals = Self.stringLiteralText(in: line)
                if literals.contains("\u{2014}") || literals.contains("\u{2013}")
                    || literals.contains("u{2014}") || literals.contains("u{2013}") {
                    lines.append(index + 1)
                }
            }
            if !lines.isEmpty { violations.append(Violation(path: url.path, lines: lines)) }
        }
        guard !violations.isEmpty else { return }
        XCTFail(Self.report(
            rule: "Rule 6 (no dashes in copy): em/en dashes must not appear in string literals under Minus/. Recast the sentence with a period, comma, colon, or the app's \u{00B7} separator.",
            violations: violations
        ))
    }

    /// Everything inside double-quoted literals on `line`, concatenated. A
    /// single character walk: quotes toggle (escaped quotes don't), and `//`
    /// outside a literal ends the line.
    private static func stringLiteralText(in line: String) -> String {
        var inLiteral = false
        var escaped = false
        var previous: Character?
        var result = ""
        for character in line {
            if inLiteral {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inLiteral = false
                    previous = character
                    continue
                }
                result.append(character)
            } else {
                if character == "\"" {
                    inLiteral = true
                } else if character == "/", previous == "/" {
                    break
                }
            }
            previous = character
        }
        return result
    }

    // MARK: - Rule 5 — springs only

    func testTimingCurvesAreBannedEverywhereUnderMinus() {
        let found = Self.findViolations(
            in: Self.swiftFiles(),
            patterns: [".timingCurve("]
        )
        guard !found.isEmpty else { return }
        XCTFail(Self.report(
            rule: "Rule 5 (springs only): `.timingCurve(` must not appear anywhere under Minus/ — the v1.7 motion vocabulary is zero-bounce springs via MMotion tokens.",
            violations: found
        ))
    }

    // MARK: - Rule 8 — the typeface allowlist

    /// The approved faces, by PostScript name. A font name that is not on
    /// this list has no business anywhere under Minus/: `.custom` silently
    /// falls back to the SYSTEM font when a name misses, so a typo or an
    /// unapproved import breaks the whole design language with no crash and
    /// no warning. Kept here rather than read from MTypeface so the guard
    /// stays independent of the code it guards.
    private static let approvedFontNames: Set<String> = [
        "GeneralSans-Regular", "GeneralSans-Bold",
        "Satoshi-Regular", "Satoshi-Bold",
        "Switzer-Regular", "Switzer-Bold",
        "CabinetGrotesk-Regular", "CabinetGrotesk-Bold",
        "Chillax-Regular", "Chillax-Bold",
    ]

    func testFontNamesAreLimitedToTheApprovedList() {
        let pattern = "\\b[A-Za-z][A-Za-z0-9]*-(Regular|Bold|Medium|Light|SemiBold|Semibold|Italic|Black|Thin|Variable)\\b"
        let regex = try? NSRegularExpression(pattern: pattern)
        var violations: [Violation] = []

        for url in Self.swiftFiles().sorted(by: { $0.path < $1.path }) {
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }
            var lines: [Int] = []
            for (index, line) in contents.components(separatedBy: .newlines).enumerated() {
                let literals = Self.stringLiteralText(in: line)
                let range = NSRange(literals.startIndex..., in: literals)
                regex?.enumerateMatches(in: literals, range: range) { match, _, _ in
                    guard let match, let r = Range(match.range, in: literals) else { return }
                    let name = String(literals[r])
                    if !Self.approvedFontNames.contains(name) { lines.append(index + 1) }
                }
            }
            if !lines.isEmpty { violations.append(Violation(path: url.path, lines: lines)) }
        }

        guard !violations.isEmpty else { return }
        XCTFail(Self.report(
            rule: "Rule 8 (typeface allowlist): only the approved faces may be named under Minus/. Add the .otf, list it in every target's UIAppFonts, add a case to MTypeface, and add its PostScript names here.",
            violations: violations
        ))
    }

    /// Font construction belongs to the design system. Elsewhere it is a way
    /// to smuggle a face past the allowlist and past `.mnType`.
    func testFontConstructionIsContainedToDesignSystemDirectory() {
        let found = Self.findViolations(
            in: Self.swiftFiles(),
            patterns: [".custom(", "CTFontCreateWithName"],
            isExempt: { $0.path.hasPrefix(Self.designSystemRootPrefix) }
        )
        guard !found.isEmpty else { return }
        XCTFail(Self.report(
            rule: "Rule 8b (font construction containment): `.custom(` and CTFontCreateWithName may appear only under Minus/DesignSystem/ — everything else goes through .mnType.",
            violations: found
        ))
    }

    // MARK: - Shared helpers

    /// Recursively collects every `*.swift` file under `Minus/`, skipping
    /// anything whose path contains `/Resources/`.
    private static func swiftFiles() -> [URL] {
        let root = URL(fileURLWithPath: appSourceRootPath, isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [],
            errorHandler: nil
        ) else {
            return []
        }

        var files: [URL] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "swift" else { continue }
            guard !url.path.contains("/Resources/") else { continue }
            files.append(url)
        }
        return files
    }

    private struct Violation {
        let path: String
        let lines: [Int]
    }

    /// Scans `files` for any of `patterns`, skipping files for which
    /// `isExempt` returns true and silently skipping files that fail to
    /// read. Returns one `Violation` per offending file listing every
    /// matching 1-based line number, sorted by path for stable output.
    private static func findViolations(
        in files: [URL],
        patterns: [String],
        caseInsensitive: Bool = false,
        isExempt: (URL) -> Bool = { _ in false }
    ) -> [Violation] {
        var found: [Violation] = []
        for file in files {
            if isExempt(file) { continue }
            guard let contents = try? String(contentsOfFile: file.path, encoding: .utf8) else { continue }

            let lines = contents.components(separatedBy: .newlines)
            var matchingLineNumbers = Set<Int>()
            for pattern in patterns {
                for (index, line) in lines.enumerated() {
                    let matched = caseInsensitive
                        ? line.range(of: pattern, options: .caseInsensitive) != nil
                        : line.contains(pattern)
                    if matched {
                        matchingLineNumbers.insert(index + 1)
                    }
                }
            }
            if !matchingLineNumbers.isEmpty {
                found.append(Violation(path: file.path, lines: matchingLineNumbers.sorted()))
            }
        }
        return found.sorted { $0.path < $1.path }
    }

    private static func report(rule: String, violations: [Violation]) -> String {
        var lines = [rule, "Offending files:"]
        for violation in violations {
            let lineList = violation.lines.map(String.init).joined(separator: ", ")
            lines.append("  \(violation.path) — line\(violation.lines.count == 1 ? "" : "s") \(lineList)")
        }
        return lines.joined(separator: "\n")
    }
}
