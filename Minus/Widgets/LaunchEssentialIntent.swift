import AppIntents
import Foundation

/// Where a launcher tap actually goes, in order. Pure and shared between the
/// app and the widget, which have different powers:
///
/// - The APP can open anything, so it walks the whole plan until something
///   takes: universal link, then custom scheme, then the user's shortcut.
/// - The WIDGET can only open universal links (`OpenURLIntent` rejects custom
///   schemes, which is why v1.8's widget taps were silent no-ops). When the
///   first step is https it opens directly with zero hops; otherwise the cell
///   bounces through minus, which then walks the same plan.
///
/// The four communication apps and "custom-" entries have no openable scheme
/// at all on iOS 27, so their plan is the user's one-action Shortcut alone.
/// NOTE: no CustomSlug dependency here. This file compiles into MinusWidget,
/// which never links the SwiftData layer.
enum EssentialLaunchURL {
    static let shortcutSlugs: Set<String> = ["phone", "messages", "facetime", "mail"]
    static let customPrefix = "custom-"

    /// The shortcut a slug expects the user to have made: "minus-phone",
    /// "minus-pilates". Also the copy minus shows when a launch finds nothing.
    static func shortcutName(for slug: String) -> String {
        let bare = slug.hasPrefix(customPrefix)
            ? String(slug.dropFirst(customPrefix.count))
            : slug
        return "minus-\(bare)"
    }

    /// Every attempt for this slug, best first. Never empty for a known slug.
    ///
    /// The scheme leads, because a scheme that misses fails silently while a
    /// universal link the app does not claim opens Safari, which is a worse
    /// outcome than nothing. The link is the second chance for apps whose
    /// scheme is wrong or gone, and the user's Shortcut is the last.
    static func launchPlan(slug: String, urlString: String) -> [URL] {
        if shortcutSlugs.contains(slug) || slug.hasPrefix(customPrefix) {
            return [shortcutURL(name: shortcutName(for: slug))].compactMap { $0 }
        }
        var plan: [URL] = []
        if let url = URL(string: urlString) { plan.append(url) }
        if let shortcut = shortcutURL(name: shortcutName(for: slug)) { plan.append(shortcut) }
        return plan
    }

    /// The single URL a widget cell should carry. App Intents can only open
    /// https, so a cell goes zero-hop ONLY with a device-verified link.
    /// Everything else returns the bounce URL, and minus walks the full plan.
    /// Cells launch by identity when they have one; otherwise they bounce
    /// through minus, which walks the URL plan.
    static func widgetTarget(slug: String, urlString: String) -> URL? {
        URL(string: "minus://open/\(slug)")
    }

    static func resolve(slug: String, urlString: String) -> URL? {
        launchPlan(slug: slug, urlString: urlString).first
    }

    private static func shortcutURL(name: String) -> URL? {
        var components = URLComponents(string: "shortcuts://run-shortcut")
        components?.queryItems = [URLQueryItem(name: "name", value: name)]
        return components?.url
    }
}

/// The zero-hop launch: runs inside the widget process via Button(intent:).
///
/// Two ways out, tried in that order:
/// 1. The bundle id, straight to LaunchServices. Proven to work from the app
///    process on this device; whether an extension is allowed the same call
///    is the open question this carries.
/// 2. Returning OpenURLIntent, which asks the SYSTEM to open a URL. Only
///    https gets through, since App Intents refuse custom schemes, so
///    everything else is a bounce URL that lands in minus.
struct LaunchEssentialIntent: AppIntent {
    static let title: LocalizedStringResource = "Open essential"
    static let isDiscoverable = false

    @Parameter(title: "Slug")
    var slug: String

    @Parameter(title: "URL")
    var urlString: String

    @Parameter(title: "Bundle")
    var bundleID: String

    init() {}

    init(slug: String, urlString: String, bundleID: String = "") {
        self.slug = slug
        self.urlString = urlString
        self.bundleID = bundleID
    }

    /// Identity only. Returning no intent is deliberate: handing back an
    /// OpenURLIntent would drag minus up over the app that just opened, which
    /// is the exact flash being removed. Cells without a bundle id never use
    /// this intent, they use a Link that bounces (see MinusWidgetViews).
    ///
    /// The private call is proven from the app process on this device
    /// (Telegram, killed, came back as a fresh pid). Whether an app EXTENSION
    /// is granted the same privilege is what a real widget tap now answers:
    /// the app opens, or the tap does nothing.
    func perform() async throws -> some IntentResult {
        if !bundleID.isEmpty { PrivateAppLauncher.open(bundleID: bundleID) }
        return .result()
    }
}
