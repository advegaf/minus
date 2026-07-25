import Foundation

/// The name an app wears under its icon, asked of the device rather than
/// inferred from the App Store.
///
/// This exists because the store cannot answer it. "MacroFactor Workouts -
/// Tracker" is the whole of what the Search API returns for `com.sbs.train`:
/// `trackName`, `trackCensoredName` and the seller all say it, and none of
/// them contains the word the home screen actually shows, which is
/// "Workouts". That word is the app's own `CFBundleDisplayName`, and it lives
/// in the app's bundle. `AppName.short` correctly reduces the store title to
/// "MacroFactor Workouts" and that is the ceiling for any rule over that
/// data. So this reads a different source.
///
/// `LSApplicationProxy` is private, and reached by name through the
/// Objective-C runtime exactly as `PrivateAppLauncher` does: no private
/// framework is linked and no private symbol lands in the binary. Two rules,
/// both learned on this device:
///
/// 1. It runs OFF the main thread. LaunchServices calls are synchronous XPC,
///    and making one from the main actor is what hung minus until the watchdog
///    killed it (0x8BADF00D, seven times in fifteen minutes).
/// 2. It may simply be refused. Enumerating installed apps returns nothing
///    here; a targeted lookup for an identifier the user just named is a
///    different privacy posture, but an unproven one. So every caller treats a
///    nil answer as normal and falls back to the store title.
///
/// Personal build only. MUST be removed before any App Store submission.
enum PrivateAppName {
    /// True when the private path is reachable at all. Cheap and cached.
    nonisolated static let isAvailable: Bool = {
        guard let proxyClass = NSClassFromString("LSApplicationProxy") as? NSObject.Type else {
            return false
        }
        return proxyClass.responds(to: NSSelectorFromString("applicationProxyForIdentifier:"))
    }()

    /// The installed app's display name, or nil if it is not installed, not
    /// readable, or the lookup is refused.
    ///
    /// `localizedShortName` first: that is precisely the name SpringBoard puts
    /// under an icon when the full one will not fit, which is the thing being
    /// recreated here.
    nonisolated static func displayName(bundleID: String) async -> String? {
        guard isAvailable, !bundleID.isEmpty else { return nil }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: lookup(bundleID: bundleID))
            }
        }
    }

    /// Synchronous and private; only ever called from a background queue.
    private nonisolated static func lookup(bundleID: String) -> String? {
        guard let proxyClass = NSClassFromString("LSApplicationProxy") as? NSObject.Type,
              let proxy = proxyClass
                .perform(NSSelectorFromString("applicationProxyForIdentifier:"), with: bundleID)?
                .takeUnretainedValue() as? NSObject
        else { return nil }

        for name in ["localizedShortName", "localizedName"] {
            let selector = NSSelectorFromString(name)
            guard proxy.responds(to: selector),
                  let value = proxy.perform(selector)?.takeUnretainedValue() as? String
            else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }
}
