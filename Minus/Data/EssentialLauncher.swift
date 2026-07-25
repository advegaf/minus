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
        return EssentialLaunchURL.launchPlan(
            slug: slug,
            urlString: app?.urlString ?? "",
            universalLink: app?.universalLink
        )
    }

    /// Returns whether anything actually opened.
    @discardableResult
    static func open(slug: String) async -> Bool {
        #if DEBUG
        // MINUS_LAUNCH=fail drives the "nothing opened" copy. The simulator
        // ships Shortcuts, so every real open succeeds there and the honest
        // failure line would otherwise be untestable.
        if ProcessInfo.processInfo.environment["MINUS_LAUNCH"] == "fail" { return false }
        #endif
        for url in plan(slug: slug) {
            if await UIApplication.shared.open(url) { return true }
        }
        return false
    }
}
