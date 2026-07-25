import Foundation

/// The apps a user can put on a launcher card. iOS publishes no way to read
/// what is installed (see TODOS), so this is minus's own list — generated from
/// scripts/catalog-apps.tsv, where every row's identity is either pinned or
/// resolved once against the App Store and cached.
///
/// v1.13: the list grew from sixty to the whole of a real phone, and the shape
/// changed with it. A row is a NAME and an IDENTITY. Schemes are gone from the
/// data: identity is exact and needs no scheme, no claimed https path, and no
/// shortcut, and inventing a scheme per app for two hundred apps would be the
/// guesswork v1.12 spent a version deleting. The few dozen schemes that were
/// actually walked on hardware survive below as the fallback for a device that
/// refuses the identity route.
///
/// Anything NOT here is still reachable: ADD AN APP resolves any name in the
/// store to an identity through the same endpoint.
struct CatalogApp: Identifiable, Hashable, Sendable {
    var slug: String
    var displayName: String
    var category: CatalogCategory
    /// How minus opens it. Required: a row without one could never launch.
    var bundleID: String

    var id: String { slug }

    /// The fallback URL, empty for every row whose scheme was never verified
    /// on a device. EssentialLaunchURL.launchPlan drops empties.
    var urlString: String { EssentialAppCatalog.verifiedSchemes[slug] ?? "" }
    var scheme: String { String(urlString.prefix(while: { $0 != ":" })) }
    var url: URL? { urlString.isEmpty ? nil : URL(string: urlString) }
}

/// Editor eyebrow order: communication first, the long tail last.
enum CatalogCategory: String, CaseIterable, Sendable {
    case communication
    case apple = "apple basics"
    case media
    case social
    case gettingAround = "getting around"
    case travel
    case money
    case mindBody = "mind & body"
    case tools
    case shopping
    case food
    case games
    case campus = "campus & personal"
}

enum EssentialAppCatalog {
    /// Max rows on one launcher card — minimalism is the product.
    static let homeCap = 7

    static let all: [CatalogApp] = generatedAll

    /// Schemes walked on a real device in the v1.8 scheme lab, kept because a
    /// verified fallback costs nothing. Everything else launches by identity
    /// alone rather than by a guess.
    static let verifiedSchemes: [String: String] = [
        "whatsapp": "whatsapp:",
        "signal": "sgnl:",
        "telegram": "tg:",
        "slack": "slack:",
        "discord": "discord:",
        "teams": "msteams:",
        "outlook": "ms-outlook:",
        "gmail": "googlegmail:",
        "zoom": "zoomus:",
        "maps": "maps:",
        "music": "music:",
        "photos": "photos-redirect:",
        "calendar": "calshow:",
        "notes": "mobilenotes:",
        "shortcuts": "shortcuts:",
        "reminders": "x-apple-reminderkit:",
        "files": "shareddocuments:",
        "books": "ibooks:",
        "podcasts": "podcasts:",
        "wallet": "shoebox:",
        "health": "x-apple-health:",
        "weather": "weather:",
        "spotify": "spotify:",
        "youtube": "youtube:",
        "netflix": "nflx:",
        "twitch": "twitch:",
        "overcast": "overcast:",
        "pocketcasts": "pktc:",
        "audible": "audible:",
        "instagram": "instagram:",
        "x": "twitter:",
        "facebook": "fb:",
        "snapchat": "snapchat:",
        "tiktok": "tiktok:",
        "reddit": "reddit:",
        "pinterest": "pinterest:",
        "linkedin": "linkedin:",
        "threads": "threads:",
        "uber": "uber:",
        "lyft": "lyft:",
        "waze": "waze:",
        "googlemaps": "comgooglemaps:",
        "venmo": "venmo:",
        "paypal": "paypal:",
        "cashapp": "squarecash:",
        "robinhood": "robinhood:",
        "strava": "strava:",
        "headspace": "headspace:",
        "duolingo": "duolingo:",
        "chrome": "googlechrome:",
        "notion": "notion:",
        "things": "things:",
        "todoist": "todoist:",
        "obsidian": "obsidian:",
        "chatgpt": "chatgpt:",
        "amazon": "com.amazon.mobile.shopping:",
    ]

    static func app(slug: String) -> CatalogApp? {
        all.first { $0.slug == slug }
    }

    static func apps(in category: CatalogCategory) -> [CatalogApp] {
        all.filter { $0.category == category }
    }
}
