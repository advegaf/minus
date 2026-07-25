import Foundation
import UIKit

/// The launcher's one launch path. minus never asks whether an app is
/// installed before letting you tap it: asking the system first proved
/// unreliable on iOS 27 even with the scheme declared, and a false negative
/// used to disable the row outright, putting the app permanently out of
/// reach.
///
/// Instead it walks the plan (universal link, scheme, the user's shortcut)
/// and takes the first thing that opens. Only a total miss is reported, and
/// then it says exactly what would fix it.
@MainActor
enum EssentialLauncher {
    /// Every attempt for a slug, best first.
    static func plan(slug: String) -> [URL] {
        let app = EssentialAppCatalog.app(slug: slug)
        return EssentialLaunchURL.launchPlan(slug: slug, urlString: app?.urlString ?? "")
    }

    /// The identity for a slug: the catalog's, or the one an added app
    /// resolved from the App Store.
    static func bundleID(for slug: String, customs: [String: String]) -> String? {
        EssentialAppCatalog.app(slug: slug)?.bundleID ?? customs[slug]
    }

    /// Returns whether anything actually opened.
    ///
    /// The bundle id goes first: it is the only route that does not depend on
    /// an app publishing a scheme, claiming an https path, or the user having
    /// made a shortcut. It reports nothing back (the private call lies), so
    /// the URL plan still runs behind it as the honest fallback for anything
    /// whose identifier we have wrong.
    @discardableResult
    static func open(slug: String, bundleID: String? = nil) async -> Bool {
        #if DEBUG
        // MINUS_LAUNCH=fail drives the "nothing opened" copy. The simulator
        // ships Shortcuts, so every real open succeeds there and the honest
        // failure line would otherwise be untestable.
        if ProcessInfo.processInfo.environment["MINUS_LAUNCH"] == "fail" { return false }
        #endif
        let identity = bundleID ?? EssentialAppCatalog.app(slug: slug)?.bundleID
        if let identity, PrivateAppLauncher.open(bundleID: identity) {
            // The identity launch is already running on its own queue and
            // reports nothing, so the only honest signal is whether minus
            // stopped being frontmost. Give LaunchServices that moment, then
            // ask. Awaiting a sleep keeps the main thread free throughout,
            // which is the whole difference between this and the version the
            // watchdog killed.
            try? await Task.sleep(for: .milliseconds(400))
            if UIApplication.shared.applicationState != .active { return true }
        }
        for url in plan(slug: slug) {
            if await UIApplication.shared.open(url) { return true }
        }
        return false
    }
}
