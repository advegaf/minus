#if DEBUG
import Foundation
import UIKit

/// A DEBUG-only spike, never shipped: does the private LaunchServices path
/// still work on this device?
///
/// `LSApplicationWorkspace` is what a jailbreak tweak would use to launch an
/// app by bundle id and to enumerate what is installed. Both are exactly what
/// minus wants and neither has a public equivalent. The catch is that the
/// class does not do the work itself: it forwards to launchservicesd, which
/// checks the caller's entitlements. Since roughly iOS 14 an ordinary
/// sandboxed app fails that check, so the expected result here is "reachable
/// but refuses". This probe finds out for certain rather than assuming.
///
/// Everything goes through the Objective-C runtime by name, so the binary
/// links no private framework and contains no private symbol.
///
/// MUST be removed before any TestFlight or App Store submission.
enum PrivateLaunchProbe {
    struct Result {
        var workspaceReachable = false
        var installedAppsCount: Int?
        var sampleBundleIDs: [String] = []
        var launchAttempted: String?
        var launchReturnedTrue: Bool?
        var notes: [String] = []

        var summary: String {
            var lines = ["workspace: \(workspaceReachable ? "reachable" : "unavailable")"]
            if let installedAppsCount {
                lines.append("installed apps: \(installedAppsCount)")
            } else {
                lines.append("installed apps: refused")
            }
            if !sampleBundleIDs.isEmpty {
                lines.append("sample: \(sampleBundleIDs.prefix(5).joined(separator: ", "))")
            }
            if let launchAttempted {
                let verdict = launchReturnedTrue == true ? "true" : "false"
                lines.append("open \(launchAttempted): \(verdict)")
            }
            lines.append(contentsOf: notes)
            return lines.joined(separator: "\n")
        }
    }

    /// `bundleID` is the app the probe tries to launch (Spotify by default,
    /// since it is installed on the test device and misbehaves via scheme).
    static func run(launching bundleID: String = "com.spotify.client") -> Result {
        var result = Result()

        // The class lives in a private framework that is already loaded into
        // every app through MobileCoreServices, so no dlopen is needed. If it
        // has been hidden from the runtime, the probe stops here.
        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type else {
            result.notes.append("LSApplicationWorkspace is not in the runtime")
            return result
        }

        let defaultSelector = NSSelectorFromString("defaultWorkspace")
        guard workspaceClass.responds(to: defaultSelector),
              let workspace = workspaceClass.perform(defaultSelector)?.takeUnretainedValue() as? NSObject
        else {
            result.notes.append("defaultWorkspace refused")
            return result
        }
        result.workspaceReachable = true

        // 1. Enumeration: the answer to "can minus read the apps you have".
        let allSelector = NSSelectorFromString("allInstalledApplications")
        if workspace.responds(to: allSelector),
           let proxies = workspace.perform(allSelector)?.takeUnretainedValue() as? [NSObject] {
            result.installedAppsCount = proxies.count
            let bundleSelector = NSSelectorFromString("applicationIdentifier")
            result.sampleBundleIDs = proxies.compactMap { proxy in
                guard proxy.responds(to: bundleSelector) else { return nil }
                return proxy.perform(bundleSelector)?.takeUnretainedValue() as? String
            }
        } else {
            result.notes.append("allInstalledApplications refused or absent")
        }

        // 2. Launching: the answer to "can minus open an app by bundle id".
        let openSelector = NSSelectorFromString("openApplicationWithBundleID:")
        if workspace.responds(to: openSelector) {
            result.launchAttempted = bundleID
            let returned = workspace.perform(openSelector, with: bundleID)?.takeUnretainedValue()
            result.launchReturnedTrue = (returned as? NSNumber)?.boolValue ?? false
        } else {
            result.notes.append("openApplicationWithBundleID: absent")
        }

        return result
    }
}
#endif
