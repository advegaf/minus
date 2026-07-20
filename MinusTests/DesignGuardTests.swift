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
            patterns: ["FF2A2A", "2A7FFF", "2AFF2A"],
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
            patterns: ["Color(red:", "Color(mnHex:", "UIColor(red:"],
            isExempt: { $0.path.hasPrefix(Self.designSystemRootPrefix) }
        )
        guard !found.isEmpty else { return }
        XCTFail(Self.report(
            rule: "Rule 4 (raw color containment): Color(red:/Color(mnHex:/UIColor(red: may appear only under Minus/DesignSystem/.",
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
