import Foundation

/// The curated set of apps a user may keep on a launcher card. FamilyActivity
/// tokens are opaque (no URL schemes), so essentials are our own catalog:
/// sixty apps across eight categories.
///
/// v1.8: minus declares no query schemes and probes nothing. Opening a URL
/// needs no declaration; only asking whether it would open does, and that
/// question answered wrong on iOS 27 (declared schemes for installed apps
/// still reported false), which used to disable the row. So the catalog now
/// carries only what it takes to launch. `confidence` and `altCandidates`
/// survive purely to drive the DEBUG scheme lab.
struct CatalogApp: Identifiable, Hashable, Sendable {
    /// How sure we are the scheme opens the app's MAIN screen. Anything below
    /// `.high` shows up in the scheme lab until a device pass confirms it.
    enum Confidence: String, Sendable { case high, medium, low }

    var slug: String
    var displayName: String
    /// Full URL string handed to openURL (e.g. "spotify:").
    var urlString: String
    /// The bare scheme. Kept for uniqueness checks and lab copy.
    var scheme: String
    var category: CatalogCategory
    var confidence: Confidence = .high
    /// Alternate schemes worth trying in the scheme lab if the primary misses.
    var altCandidates: [String] = []

    var id: String { slug }
    var url: URL? { URL(string: urlString) }
}

/// Editor eyebrow order: communication first, tools last.
enum CatalogCategory: String, CaseIterable, Sendable {
    case communication
    case apple = "apple basics"
    case media
    case social
    case gettingAround = "getting around"
    case money
    case mindBody = "mind & body"
    case tools
}

enum EssentialAppCatalog {
    /// Max rows on one launcher card — minimalism is the product.
    static let homeCap = 7

    static let all: [CatalogApp] = [
        // MARK: communication (13)
        CatalogApp(slug: "phone", displayName: "Phone", urlString: "tel:", scheme: "tel", category: .communication),
        // messages:// lands on the conversation list; sms: opens a COMPOSE
        // sheet (T1 — the launcher must open apps, never start drafts). On
        // iOS 27 the four comm apps route via Shortcuts anyway (EssentialLaunchURL).
        CatalogApp(slug: "messages", displayName: "Messages", urlString: "messages:", scheme: "messages", category: .communication),
        CatalogApp(slug: "facetime", displayName: "FaceTime", urlString: "facetime:", scheme: "facetime", category: .communication),
        // message:// opens the Mail inbox; mailto: composes.
        CatalogApp(slug: "mail", displayName: "Mail", urlString: "message:", scheme: "message", category: .communication),
        CatalogApp(slug: "whatsapp", displayName: "WhatsApp", urlString: "whatsapp:", scheme: "whatsapp", category: .communication),
        CatalogApp(slug: "signal", displayName: "Signal", urlString: "sgnl:", scheme: "sgnl", category: .communication),
        CatalogApp(slug: "telegram", displayName: "Telegram", urlString: "tg:", scheme: "tg", category: .communication),
        CatalogApp(slug: "slack", displayName: "Slack", urlString: "slack:", scheme: "slack", category: .communication),
        CatalogApp(slug: "discord", displayName: "Discord", urlString: "discord:", scheme: "discord", category: .communication),
        CatalogApp(slug: "teams", displayName: "Teams", urlString: "msteams:", scheme: "msteams", category: .communication),
        CatalogApp(slug: "outlook", displayName: "Outlook", urlString: "ms-outlook:", scheme: "ms-outlook", category: .communication),
        CatalogApp(slug: "gmail", displayName: "Gmail", urlString: "googlegmail:", scheme: "googlegmail", category: .communication),
        CatalogApp(slug: "zoom", displayName: "Zoom", urlString: "zoomus:", scheme: "zoomus", category: .communication),

        // MARK: apple basics (13)
        CatalogApp(slug: "maps", displayName: "Maps", urlString: "maps:", scheme: "maps", category: .apple),
        CatalogApp(slug: "music", displayName: "Music", urlString: "music:", scheme: "music", category: .apple),
        CatalogApp(slug: "photos", displayName: "Photos", urlString: "photos-redirect:", scheme: "photos-redirect", category: .apple),
        CatalogApp(slug: "calendar", displayName: "Calendar", urlString: "calshow:", scheme: "calshow", category: .apple),
        CatalogApp(slug: "notes", displayName: "Notes", urlString: "mobilenotes:", scheme: "mobilenotes", category: .apple),
        CatalogApp(slug: "shortcuts", displayName: "Shortcuts", urlString: "shortcuts:", scheme: "shortcuts", category: .apple),
        CatalogApp(slug: "reminders", displayName: "Reminders", urlString: "x-apple-reminderkit:", scheme: "x-apple-reminderkit", category: .apple),
        CatalogApp(slug: "files", displayName: "Files", urlString: "shareddocuments:", scheme: "shareddocuments", category: .apple),
        CatalogApp(slug: "books", displayName: "Books", urlString: "ibooks:", scheme: "ibooks", category: .apple),
        CatalogApp(slug: "podcasts", displayName: "Podcasts", urlString: "podcasts:", scheme: "podcasts", category: .apple, altCandidates: ["pcast:"]),
        CatalogApp(slug: "wallet", displayName: "Wallet", urlString: "shoebox:", scheme: "shoebox", category: .apple),
        CatalogApp(slug: "health", displayName: "Health", urlString: "x-apple-health:", scheme: "x-apple-health", category: .apple),
        CatalogApp(slug: "weather", displayName: "Weather", urlString: "weather:", scheme: "weather", category: .apple, confidence: .medium),

        // MARK: media (7)
        CatalogApp(slug: "spotify", displayName: "Spotify", urlString: "spotify:", scheme: "spotify", category: .media),
        CatalogApp(slug: "youtube", displayName: "YouTube", urlString: "youtube:", scheme: "youtube", category: .media),
        CatalogApp(slug: "netflix", displayName: "Netflix", urlString: "nflx:", scheme: "nflx", category: .media),
        CatalogApp(slug: "twitch", displayName: "Twitch", urlString: "twitch:", scheme: "twitch", category: .media),
        CatalogApp(slug: "overcast", displayName: "Overcast", urlString: "overcast:", scheme: "overcast", category: .media),
        CatalogApp(slug: "pocketcasts", displayName: "Pocket Casts", urlString: "pktc:", scheme: "pktc", category: .media, confidence: .medium),
        CatalogApp(slug: "audible", displayName: "Audible", urlString: "audible:", scheme: "audible", category: .media, confidence: .medium),

        // MARK: social (9)
        CatalogApp(slug: "instagram", displayName: "Instagram", urlString: "instagram:", scheme: "instagram", category: .social),
        CatalogApp(slug: "x", displayName: "X", urlString: "twitter:", scheme: "twitter", category: .social),
        CatalogApp(slug: "facebook", displayName: "Facebook", urlString: "fb:", scheme: "fb", category: .social),
        CatalogApp(slug: "snapchat", displayName: "Snapchat", urlString: "snapchat:", scheme: "snapchat", category: .social),
        CatalogApp(slug: "tiktok", displayName: "TikTok", urlString: "tiktok:", scheme: "tiktok", category: .social, confidence: .medium, altCandidates: ["snssdk1233:"]),
        CatalogApp(slug: "reddit", displayName: "Reddit", urlString: "reddit:", scheme: "reddit", category: .social),
        CatalogApp(slug: "pinterest", displayName: "Pinterest", urlString: "pinterest:", scheme: "pinterest", category: .social),
        CatalogApp(slug: "linkedin", displayName: "LinkedIn", urlString: "linkedin:", scheme: "linkedin", category: .social),
        CatalogApp(slug: "threads", displayName: "Threads", urlString: "threads:", scheme: "threads", category: .social, confidence: .low, altCandidates: ["barcelona:"]),

        // MARK: getting around (4)
        CatalogApp(slug: "uber", displayName: "Uber", urlString: "uber:", scheme: "uber", category: .gettingAround),
        CatalogApp(slug: "lyft", displayName: "Lyft", urlString: "lyft:", scheme: "lyft", category: .gettingAround),
        CatalogApp(slug: "waze", displayName: "Waze", urlString: "waze:", scheme: "waze", category: .gettingAround),
        CatalogApp(slug: "googlemaps", displayName: "Google Maps", urlString: "comgooglemaps:", scheme: "comgooglemaps", category: .gettingAround),

        // MARK: money (4)
        CatalogApp(slug: "venmo", displayName: "Venmo", urlString: "venmo:", scheme: "venmo", category: .money),
        CatalogApp(slug: "paypal", displayName: "PayPal", urlString: "paypal:", scheme: "paypal", category: .money, confidence: .medium),
        CatalogApp(slug: "cashapp", displayName: "Cash App", urlString: "squarecash:", scheme: "squarecash", category: .money),
        CatalogApp(slug: "robinhood", displayName: "Robinhood", urlString: "robinhood:", scheme: "robinhood", category: .money),

        // MARK: mind & body (3)
        CatalogApp(slug: "strava", displayName: "Strava", urlString: "strava:", scheme: "strava", category: .mindBody),
        CatalogApp(slug: "headspace", displayName: "Headspace", urlString: "headspace:", scheme: "headspace", category: .mindBody, confidence: .medium),
        CatalogApp(slug: "duolingo", displayName: "Duolingo", urlString: "duolingo:", scheme: "duolingo", category: .mindBody),

        // MARK: tools (7)
        CatalogApp(slug: "chrome", displayName: "Chrome", urlString: "googlechrome:", scheme: "googlechrome", category: .tools),
        CatalogApp(slug: "notion", displayName: "Notion", urlString: "notion:", scheme: "notion", category: .tools),
        CatalogApp(slug: "things", displayName: "Things", urlString: "things:", scheme: "things", category: .tools),
        CatalogApp(slug: "todoist", displayName: "Todoist", urlString: "todoist:", scheme: "todoist", category: .tools, confidence: .medium),
        CatalogApp(slug: "obsidian", displayName: "Obsidian", urlString: "obsidian:", scheme: "obsidian", category: .tools, confidence: .medium),
        CatalogApp(slug: "chatgpt", displayName: "ChatGPT", urlString: "chatgpt:", scheme: "chatgpt", category: .tools, altCandidates: ["openai:"]),
        CatalogApp(slug: "amazon", displayName: "Amazon", urlString: "com.amazon.mobile.shopping:", scheme: "com.amazon.mobile.shopping", category: .tools),
    ]

    static func app(slug: String) -> CatalogApp? {
        all.first { $0.slug == slug }
    }

    static func apps(in category: CatalogCategory) -> [CatalogApp] {
        all.filter { $0.category == category }
    }
}
