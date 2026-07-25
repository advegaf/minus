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
    static func launchPlan(slug: String, urlString: String, universalLink: String?) -> [URL] {
        if shortcutSlugs.contains(slug) || slug.hasPrefix(customPrefix) {
            return [shortcutURL(name: shortcutName(for: slug))].compactMap { $0 }
        }
        var plan: [URL] = []
        if let url = URL(string: urlString) { plan.append(url) }
        if let universalLink, let url = URL(string: universalLink) { plan.append(url) }
        if let shortcut = shortcutURL(name: shortcutName(for: slug)) { plan.append(shortcut) }
        return plan
    }

    /// The single URL a widget cell should carry. App Intents can only open
    /// https, so a cell goes zero-hop ONLY with a device-verified link.
    /// Everything else returns the bounce URL, and minus walks the full plan.
    static func widgetTarget(
        slug: String,
        urlString: String,
        universalLink: String?,
        linkVerified: Bool
    ) -> URL? {
        if linkVerified, let universalLink, let url = URL(string: universalLink) { return url }
        return URL(string: "minus://open/\(slug)")
    }

    static func resolve(slug: String, urlString: String, universalLink: String? = nil) -> URL? {
        launchPlan(slug: slug, urlString: urlString, universalLink: universalLink).first
    }

    private static func shortcutURL(name: String) -> URL? {
        var components = URLComponents(string: "shortcuts://run-shortcut")
        components?.queryItems = [URLQueryItem(name: "name", value: name)]
        return components?.url
    }
}

/// The zero-hop launch: runs inside the widget process via Button(intent:),
/// and returning OpenURLIntent makes the SYSTEM open the target, so minus
/// never comes to the foreground. Only ever handed https targets, because
/// App Intents cannot open custom schemes.
struct LaunchEssentialIntent: AppIntent {
    static let title: LocalizedStringResource = "Open essential"
    static let isDiscoverable = false

    @Parameter(title: "Slug")
    var slug: String

    @Parameter(title: "URL")
    var urlString: String

    init() {}

    init(slug: String, urlString: String) {
        self.slug = slug
        self.urlString = urlString
    }

    func perform() async throws -> some IntentResult & OpensIntent {
        // urlString is already the resolved target the cell decided on; the
        // bounce URL is the honest fallback if it somehow fails to parse.
        let url = URL(string: urlString)
            ?? URL(string: "minus://open/\(slug)")
            ?? URL(string: "minus://focus")!
        return .result(opensIntent: OpenURLIntent(url))
    }
}
