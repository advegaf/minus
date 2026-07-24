import Foundation

/// The curated set of apps a user may keep on a launcher card. FamilyActivity
/// tokens are opaque (no URL schemes), so essentials are our own catalog.
/// v1.6: sixty apps across eight categories. Only `declared: true` schemes
/// appear in LSApplicationQueriesSchemes (Apple caps the list at 50) — those
/// get honest installed-dimming via canOpenURL. Undeclared entries still OPEN
/// fine (UIApplication.open needs no declaration); they just never dim.
/// Lockstep with project.yml is enforced both directions by EssentialCatalogTests.
struct CatalogApp: Identifiable, Hashable, Sendable {
    /// How sure we are the scheme opens the app's MAIN screen. Low-confidence
    /// rows ship undeclared and get verified on device via the scheme lab.
    enum Confidence: String, Sendable { case high, medium, low }

    var slug: String
    var displayName: String
    /// Full URL string handed to openURL (e.g. "spotify:").
    var urlString: String
    /// The bare scheme, for the LSApplicationQueriesSchemes lockstep test.
    var scheme: String
    var category: CatalogCategory
    /// true → scheme is in LSApplicationQueriesSchemes → canOpenURL is honest.
    var declared: Bool
    var confidence: Confidence = .high
    /// Alternate schemes worth trying in the scheme lab if the primary misses.
    var altCandidates: [String] = []

    var id: String { slug }
    var url: URL? { URL(string: urlString) }
}

/// Editor eyebrow order — communication first, tools last.
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
        CatalogApp(slug: "phone", displayName: "Phone", urlString: "tel:", scheme: "tel", category: .communication, declared: true),
        // messages:// lands on the conversation list; sms: opens a COMPOSE
        // sheet (T1 — the launcher must open apps, never start drafts). On
        // iOS 27 the four comm apps route via Shortcuts anyway (EssentialLaunchURL).
        CatalogApp(slug: "messages", displayName: "Messages", urlString: "messages:", scheme: "messages", category: .communication, declared: true),
        CatalogApp(slug: "facetime", displayName: "FaceTime", urlString: "facetime:", scheme: "facetime", category: .communication, declared: true),
        // message:// opens the Mail inbox; mailto: composes.
        CatalogApp(slug: "mail", displayName: "Mail", urlString: "message:", scheme: "message", category: .communication, declared: true),
        CatalogApp(slug: "whatsapp", displayName: "WhatsApp", urlString: "whatsapp:", scheme: "whatsapp", category: .communication, declared: true),
        CatalogApp(slug: "signal", displayName: "Signal", urlString: "sgnl:", scheme: "sgnl", category: .communication, declared: true),
        CatalogApp(slug: "telegram", displayName: "Telegram", urlString: "tg:", scheme: "tg", category: .communication, declared: true),
        CatalogApp(slug: "slack", displayName: "Slack", urlString: "slack:", scheme: "slack", category: .communication, declared: true),
        CatalogApp(slug: "discord", displayName: "Discord", urlString: "discord:", scheme: "discord", category: .communication, declared: true),
        CatalogApp(slug: "teams", displayName: "Teams", urlString: "msteams:", scheme: "msteams", category: .communication, declared: true),
        CatalogApp(slug: "outlook", displayName: "Outlook", urlString: "ms-outlook:", scheme: "ms-outlook", category: .communication, declared: true),
        CatalogApp(slug: "gmail", displayName: "Gmail", urlString: "googlegmail:", scheme: "googlegmail", category: .communication, declared: true),
        CatalogApp(slug: "zoom", displayName: "Zoom", urlString: "zoomus:", scheme: "zoomus", category: .communication, declared: true),

        // MARK: apple basics (13)
        CatalogApp(slug: "maps", displayName: "Maps", urlString: "maps:", scheme: "maps", category: .apple, declared: true),
        CatalogApp(slug: "music", displayName: "Music", urlString: "music:", scheme: "music", category: .apple, declared: true),
        CatalogApp(slug: "photos", displayName: "Photos", urlString: "photos-redirect:", scheme: "photos-redirect", category: .apple, declared: true),
        CatalogApp(slug: "calendar", displayName: "Calendar", urlString: "calshow:", scheme: "calshow", category: .apple, declared: true),
        CatalogApp(slug: "notes", displayName: "Notes", urlString: "mobilenotes:", scheme: "mobilenotes", category: .apple, declared: true),
        CatalogApp(slug: "shortcuts", displayName: "Shortcuts", urlString: "shortcuts:", scheme: "shortcuts", category: .apple, declared: true),
        CatalogApp(slug: "reminders", displayName: "Reminders", urlString: "x-apple-reminderkit:", scheme: "x-apple-reminderkit", category: .apple, declared: true),
        CatalogApp(slug: "files", displayName: "Files", urlString: "shareddocuments:", scheme: "shareddocuments", category: .apple, declared: true),
        CatalogApp(slug: "books", displayName: "Books", urlString: "ibooks:", scheme: "ibooks", category: .apple, declared: true),
        CatalogApp(slug: "podcasts", displayName: "Podcasts", urlString: "podcasts:", scheme: "podcasts", category: .apple, declared: true, altCandidates: ["pcast:"]),
        CatalogApp(slug: "wallet", displayName: "Wallet", urlString: "shoebox:", scheme: "shoebox", category: .apple, declared: true),
        CatalogApp(slug: "health", displayName: "Health", urlString: "x-apple-health:", scheme: "x-apple-health", category: .apple, declared: true),
        CatalogApp(slug: "weather", displayName: "Weather", urlString: "weather:", scheme: "weather", category: .apple, declared: false, confidence: .medium),

        // MARK: media (7)
        CatalogApp(slug: "spotify", displayName: "Spotify", urlString: "spotify:", scheme: "spotify", category: .media, declared: true),
        CatalogApp(slug: "youtube", displayName: "YouTube", urlString: "youtube:", scheme: "youtube", category: .media, declared: true),
        CatalogApp(slug: "netflix", displayName: "Netflix", urlString: "nflx:", scheme: "nflx", category: .media, declared: true),
        CatalogApp(slug: "twitch", displayName: "Twitch", urlString: "twitch:", scheme: "twitch", category: .media, declared: true),
        CatalogApp(slug: "overcast", displayName: "Overcast", urlString: "overcast:", scheme: "overcast", category: .media, declared: true),
        CatalogApp(slug: "pocketcasts", displayName: "Pocket Casts", urlString: "pktc:", scheme: "pktc", category: .media, declared: false, confidence: .medium),
        CatalogApp(slug: "audible", displayName: "Audible", urlString: "audible:", scheme: "audible", category: .media, declared: false, confidence: .medium),

        // MARK: social (9)
        CatalogApp(slug: "instagram", displayName: "Instagram", urlString: "instagram:", scheme: "instagram", category: .social, declared: true),
        CatalogApp(slug: "x", displayName: "X", urlString: "twitter:", scheme: "twitter", category: .social, declared: true),
        CatalogApp(slug: "facebook", displayName: "Facebook", urlString: "fb:", scheme: "fb", category: .social, declared: true),
        CatalogApp(slug: "snapchat", displayName: "Snapchat", urlString: "snapchat:", scheme: "snapchat", category: .social, declared: true),
        CatalogApp(slug: "tiktok", displayName: "TikTok", urlString: "tiktok:", scheme: "tiktok", category: .social, declared: false, confidence: .medium, altCandidates: ["snssdk1233:"]),
        CatalogApp(slug: "reddit", displayName: "Reddit", urlString: "reddit:", scheme: "reddit", category: .social, declared: true),
        CatalogApp(slug: "pinterest", displayName: "Pinterest", urlString: "pinterest:", scheme: "pinterest", category: .social, declared: true),
        CatalogApp(slug: "linkedin", displayName: "LinkedIn", urlString: "linkedin:", scheme: "linkedin", category: .social, declared: true),
        CatalogApp(slug: "threads", displayName: "Threads", urlString: "threads:", scheme: "threads", category: .social, declared: false, confidence: .low, altCandidates: ["barcelona:"]),

        // MARK: getting around (4)
        CatalogApp(slug: "uber", displayName: "Uber", urlString: "uber:", scheme: "uber", category: .gettingAround, declared: true),
        CatalogApp(slug: "lyft", displayName: "Lyft", urlString: "lyft:", scheme: "lyft", category: .gettingAround, declared: true),
        CatalogApp(slug: "waze", displayName: "Waze", urlString: "waze:", scheme: "waze", category: .gettingAround, declared: true),
        CatalogApp(slug: "googlemaps", displayName: "Google Maps", urlString: "comgooglemaps:", scheme: "comgooglemaps", category: .gettingAround, declared: true),

        // MARK: money (4)
        CatalogApp(slug: "venmo", displayName: "Venmo", urlString: "venmo:", scheme: "venmo", category: .money, declared: true),
        CatalogApp(slug: "paypal", displayName: "PayPal", urlString: "paypal:", scheme: "paypal", category: .money, declared: false, confidence: .medium),
        CatalogApp(slug: "cashapp", displayName: "Cash App", urlString: "cashapp:", scheme: "cashapp", category: .money, declared: false, confidence: .low, altCandidates: ["squarecash:"]),
        CatalogApp(slug: "robinhood", displayName: "Robinhood", urlString: "robinhood:", scheme: "robinhood", category: .money, declared: false, confidence: .medium),

        // MARK: mind & body (3)
        CatalogApp(slug: "strava", displayName: "Strava", urlString: "strava:", scheme: "strava", category: .mindBody, declared: true),
        CatalogApp(slug: "headspace", displayName: "Headspace", urlString: "headspace:", scheme: "headspace", category: .mindBody, declared: false, confidence: .medium),
        CatalogApp(slug: "duolingo", displayName: "Duolingo", urlString: "duolingo:", scheme: "duolingo", category: .mindBody, declared: true),

        // MARK: tools (7)
        CatalogApp(slug: "chrome", displayName: "Chrome", urlString: "googlechrome:", scheme: "googlechrome", category: .tools, declared: true),
        CatalogApp(slug: "notion", displayName: "Notion", urlString: "notion:", scheme: "notion", category: .tools, declared: true),
        CatalogApp(slug: "things", displayName: "Things", urlString: "things:", scheme: "things", category: .tools, declared: true),
        CatalogApp(slug: "todoist", displayName: "Todoist", urlString: "todoist:", scheme: "todoist", category: .tools, declared: false, confidence: .medium),
        CatalogApp(slug: "obsidian", displayName: "Obsidian", urlString: "obsidian:", scheme: "obsidian", category: .tools, declared: false, confidence: .medium),
        CatalogApp(slug: "chatgpt", displayName: "ChatGPT", urlString: "chatgpt:", scheme: "chatgpt", category: .tools, declared: false, confidence: .low, altCandidates: ["openai:"]),
        CatalogApp(slug: "amazon", displayName: "Amazon", urlString: "amazon:", scheme: "amazon", category: .tools, declared: false, confidence: .low, altCandidates: ["com.amazon.mobile.shopping:"]),
    ]

    /// Slugs whose schemes minus is allowed to canOpenURL (dimming honesty).
    static let declaredSchemes: Set<String> = Set(all.filter(\.declared).map(\.scheme))

    /// The four the launcher itself depends on — must never lose declaration.
    static let mustDeclare: Set<String> = ["tel", "messages", "facetime", "message", "shortcuts"]

    static func app(slug: String) -> CatalogApp? {
        all.first { $0.slug == slug }
    }

    static func apps(in category: CatalogCategory) -> [CatalogApp] {
        all.filter { $0.category == category }
    }
}
