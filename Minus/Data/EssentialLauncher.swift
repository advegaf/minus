import Foundation
import UIKit

/// The launcher's one launch path. v1.8: minus never asks whether an app is
/// installed before letting you tap it. Asking the system first proved
/// unreliable on iOS 27 even with the scheme declared, and a false negative
/// used to disable the row outright, putting the app permanently out of
/// reach. So we simply open, and if nothing opens we try the user's
/// shortcut, and if that finds nothing either we say so quietly.
@MainActor
enum EssentialLauncher {
    /// Returns whether anything actually opened.
    static func open(slug: String, url: URL?) async -> Bool {
        #if DEBUG
        // MINUS_LAUNCH=fail drives the "nothing opened" copy. The simulator
        // ships Shortcuts, so every real open succeeds there and the honest
        // failure line would otherwise be untestable.
        if ProcessInfo.processInfo.environment["MINUS_LAUNCH"] == "fail" { return false }
        #endif
        guard let url else { return false }
        if await UIApplication.shared.open(url) { return true }
        guard let fallback = EssentialLaunchURL.shortcutFallback(slug: slug) else { return false }
        return await UIApplication.shared.open(fallback)
    }
}
