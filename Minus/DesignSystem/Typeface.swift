import SwiftUI
import UIKit

/// The approved typefaces, and the only place their PostScript names live.
///
/// minus is one typeface at a time, but which one is the user's call. Every
/// face here is from Fontshare under the ITF Free Font License, ships Regular
/// and Bold (the two weights the scale uses), and was chosen for its
/// numerals first: the home screen is a 96pt clock, so a face that cannot
/// carry big figures cannot carry this app.
///
/// This file is compiled into the app, the widget, and the report extension —
/// the same contract-file share `SharedState` and `LauncherSnapshot` make.
/// Adding a case here means adding the .otf, listing it in that target's
/// UIAppFonts, and updating the allowlist in DesignGuardTests.
enum MTypeface: String, CaseIterable, Sendable {
    case generalSans
    case satoshi
    case switzer
    case cabinetGrotesk
    case chillax

    /// The one face the suite guarantees, and the one a broken choice falls
    /// back to.
    static let fallback = MTypeface.generalSans

    /// Lowercase, because every other name in the app's UI is.
    var displayName: String {
        switch self {
        case .generalSans: "general sans"
        case .satoshi: "satoshi"
        case .switzer: "switzer"
        case .cabinetGrotesk: "cabinet grotesk"
        case .chillax: "chillax"
        }
    }

    /// One sentence a person can choose by, in the app's voice.
    var note: String {
        switch self {
        case .generalSans: "the original. even, quiet, unbothered."
        case .satoshi: "a touch more geometric. the same calm."
        case .switzer: "swiss and neutral. the clock reads like signage."
        case .cabinetGrotesk: "tighter, with opinions. the monument gets a voice."
        case .chillax: "softer corners. the warmest of the five."
        }
    }

    var regular: String {
        switch self {
        case .generalSans: "GeneralSans-Regular"
        case .satoshi: "Satoshi-Regular"
        case .switzer: "Switzer-Regular"
        case .cabinetGrotesk: "CabinetGrotesk-Regular"
        case .chillax: "Chillax-Regular"
        }
    }

    var bold: String {
        switch self {
        case .generalSans: "GeneralSans-Bold"
        case .satoshi: "Satoshi-Bold"
        case .switzer: "Switzer-Bold"
        case .cabinetGrotesk: "CabinetGrotesk-Bold"
        case .chillax: "Chillax-Bold"
        }
    }

    /// Both weights resolve. `.custom` falls back to the SYSTEM font when a
    /// name misses, which no guard can see and which breaks the whole design
    /// language, so nothing is offered or restored without this check.
    var isRegistered: Bool {
        UIFont(name: regular, size: 17) != nil && UIFont(name: bold, size: 17) != nil
    }

    /// What the picker may offer. A face missing from the bundle shrinks the
    /// list rather than presenting a choice that would silently fall back.
    static var registered: [MTypeface] {
        allCases.filter(\.isRegistered)
    }

    /// Unknown, absent, or unregistered all resolve to the fallback.
    static func resolve(_ raw: String?) -> MTypeface {
        guard let raw, let face = MTypeface(rawValue: raw), face.isRegistered else {
            return fallback
        }
        return face
    }
}

// MARK: - The cross-process mirror

/// The widget and the report render in their own processes and cannot read
/// SwiftData, so the chosen face is mirrored into the app group. The app is
/// the only writer (LauncherBridge.publish), exactly as it is for the
/// launcher snapshot: one value, one channel.
extension MTypeface {
    private static let defaultsKey = "minus.typeface"

    private static var appGroupID: String? {
        Bundle.main.object(forInfoDictionaryKey: "MinusAppGroup") as? String
    }

    private static var defaults: UserDefaults? {
        guard let appGroupID else { return nil }
        return UserDefaults(suiteName: appGroupID)
    }

    static var published: MTypeface {
        resolve(defaults?.string(forKey: defaultsKey))
    }

    /// nil clears the key — the UITestMode reset, so a chosen face never
    /// leaks between runs.
    static func publish(_ face: MTypeface?) {
        guard let defaults else { return }
        if let face {
            defaults.set(face.rawValue, forKey: defaultsKey)
        } else {
            defaults.removeObject(forKey: defaultsKey)
        }
    }
}

// MARK: - The environment

extension EnvironmentValues {
    /// Every `.mnType` call reads this, so a pick re-renders text and nothing
    /// else: navigation state, scroll position and @State all survive it.
    @Entry var mnTypeface: MTypeface = .fallback
}
