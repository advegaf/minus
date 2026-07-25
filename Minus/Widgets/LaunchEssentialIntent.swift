import AppIntents
import Foundation

/// Where a launcher tap actually goes. Pure and shared: the four communication
/// apps can only reach their REAL main screens through the user's one-action
/// Shortcuts (iOS 27 turns their schemes into quick-action sheets), and v1.6
/// custom entries ("custom-" slugs) have no known scheme at all — both route
/// through shortcuts://run-shortcut. Everything else opens directly by scheme.
/// NOTE: no CustomSlug dependency — this file compiles into MinusWidget,
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

    static func resolve(slug: String, urlString: String) -> URL? {
        if shortcutSlugs.contains(slug) || slug.hasPrefix(customPrefix) {
            return shortcutURL(name: shortcutName(for: slug))
        }
        return URL(string: urlString)
    }

    /// The second chance for a scheme that opened nothing. nil when `resolve`
    /// already returns the shortcuts route, so a caller never retries the URL
    /// that just failed.
    static func shortcutFallback(slug: String) -> URL? {
        guard !shortcutSlugs.contains(slug), !slug.hasPrefix(customPrefix) else { return nil }
        return shortcutURL(name: shortcutName(for: slug))
    }

    private static func shortcutURL(name: String) -> URL? {
        var components = URLComponents(string: "shortcuts://run-shortcut")
        components?.queryItems = [URLQueryItem(name: "name", value: name)]
        return components?.url
    }
}

/// The zero-hop launch (v1.5): runs inside the widget process via
/// Button(intent:), and returning OpenURLIntent makes the SYSTEM open the
/// target — minus itself never comes to the foreground.
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
        let url = EssentialLaunchURL.resolve(slug: slug, urlString: urlString)
            ?? URL(string: "minus://focus")!
        return .result(opensIntent: OpenURLIntent(url))
    }
}
