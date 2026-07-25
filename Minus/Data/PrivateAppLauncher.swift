import Foundation

/// Launching an app by its bundle identifier, which is what a launcher wants
/// and what no public API offers.
///
/// `LSApplicationWorkspace` is private. On this device, iOS 27, it WORKS:
/// killing Telegram and calling this brought it back as a fresh process. Two
/// hard-won rules govern how it may be used.
///
/// 1. It LIES. The call reports `false` even when the app comes forward, so
///    the return value is ignored and every caller keeps a URL plan behind it.
/// 2. It BLOCKS. Underneath it is a synchronous XPC round trip to
///    launchservicesd, and the reply does not arrive while the target app is
///    taking the foreground. Called on the main thread it hung minus until the
///    watchdog killed it (0x8BADF00D, seven times in fifteen minutes). So it
///    is always dispatched off the main thread, and nothing ever waits on it.
///
/// Everything goes through the Objective-C runtime by name: no private
/// framework is linked and no private symbol lands in the binary. Fine for a
/// personal build; MUST be removed before any App Store or TestFlight
/// submission, where it is grounds for rejection.
enum PrivateAppLauncher {
    /// True when the private path is reachable at all. Cheap and cached.
    nonisolated static let isAvailable: Bool = {
        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type else {
            return false
        }
        return workspaceClass.responds(to: NSSelectorFromString("defaultWorkspace"))
    }()

    /// Asks LaunchServices to open `bundleID`, off the main thread, without
    /// waiting. Returns whether the attempt was dispatched, NOT whether the
    /// app came forward: that answer does not exist (see rule 1).
    @discardableResult
    nonisolated static func open(bundleID: String) -> Bool {
        guard isAvailable, !bundleID.isEmpty else { return false }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
                  let workspace = workspaceClass
                    .perform(NSSelectorFromString("defaultWorkspace"))?
                    .takeUnretainedValue() as? NSObject
            else { return }
            let selector = NSSelectorFromString("openApplicationWithBundleID:")
            guard workspace.responds(to: selector) else { return }
            // Blocks THIS queue, never the main thread.
            workspace.perform(selector, with: bundleID)
        }
        return true
    }
}
