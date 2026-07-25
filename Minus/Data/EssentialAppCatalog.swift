import Foundation

/// The curated set of apps a user may keep on a launcher card. FamilyActivity
/// tokens are opaque (no URL schemes), so essentials are our own catalog:
/// sixty apps across eight categories.
///
/// v1.8: minus declares no query schemes and probes nothing. Opening a URL
/// needs no declaration; only asking whether it would open does, and that
/// question answered wrong on iOS 27 (declared schemes for installed apps
/// still reported false), which used to disable the row.
///
/// v1.12: every row carries a `bundleID`, and minus launches by identity.
/// That supersedes the URL guessing this file used to carry (per-scheme
/// confidence, alternate schemes, universal links and their verification): an
/// identity is exact, so there is nothing left to guess. `urlString` survives
/// only as the fallback for a device that refuses the identity route, and any
/// app NOT in this list is added by name through AppSearch, which resolves
/// its identity from the App Store.
///
/// All sixty identities below were written from memory and then CHECKED, one
/// by one, against the App Store's own records through that same endpoint:
/// 60/60 correct. The one surprise was Pinterest, whose identifier really is
/// the bare word "pinterest" with no reverse-DNS at all — a unit test had to
/// be loosened rather than the data corrected. Re-run the check any time the
/// list changes; it is a single pass over `displayName`.
struct CatalogApp: Identifiable, Hashable, Sendable {
    var slug: String
    var displayName: String
    /// Full URL string handed to openURL (e.g. "spotify:").
    var urlString: String
    /// The bare scheme. Kept for uniqueness checks and lab copy.
    var scheme: String
    var category: CatalogCategory
    /// The app's bundle identifier, which LaunchServices opens directly. This
    /// is the only route that needs no scheme, no claimed https path, and no
    /// shortcut the user made: it works on identity alone. A wrong id is a
    /// silent no-op, so the URL plan still runs behind it.
    var bundleID: String? = nil

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
        CatalogApp(slug: "phone", displayName: "Phone", urlString: "tel:", scheme: "tel", category: .communication, bundleID: "com.apple.mobilephone"),
        // messages:// lands on the conversation list; sms: opens a COMPOSE
        // sheet (T1 — the launcher must open apps, never start drafts). On
        // iOS 27 the four comm apps route via Shortcuts anyway (EssentialLaunchURL).
        CatalogApp(slug: "messages", displayName: "Messages", urlString: "messages:", scheme: "messages", category: .communication, bundleID: "com.apple.MobileSMS"),
        CatalogApp(slug: "facetime", displayName: "FaceTime", urlString: "facetime:", scheme: "facetime", category: .communication, bundleID: "com.apple.facetime"),
        // message:// opens the Mail inbox; mailto: composes.
        CatalogApp(slug: "mail", displayName: "Mail", urlString: "message:", scheme: "message", category: .communication, bundleID: "com.apple.mobilemail"),
        CatalogApp(slug: "whatsapp", displayName: "WhatsApp", urlString: "whatsapp:", scheme: "whatsapp", category: .communication, bundleID: "net.whatsapp.WhatsApp"),
        CatalogApp(slug: "signal", displayName: "Signal", urlString: "sgnl:", scheme: "sgnl", category: .communication, bundleID: "org.whispersystems.signal"),
        CatalogApp(slug: "telegram", displayName: "Telegram", urlString: "tg:", scheme: "tg", category: .communication, bundleID: "ph.telegra.Telegraph"),
        CatalogApp(slug: "slack", displayName: "Slack", urlString: "slack:", scheme: "slack", category: .communication, bundleID: "com.tinyspeck.chatlyio"),
        CatalogApp(slug: "discord", displayName: "Discord", urlString: "discord:", scheme: "discord", category: .communication, bundleID: "com.hammerandchisel.discord"),
        CatalogApp(slug: "teams", displayName: "Teams", urlString: "msteams:", scheme: "msteams", category: .communication, bundleID: "com.microsoft.skype.teams"),
        CatalogApp(slug: "outlook", displayName: "Outlook", urlString: "ms-outlook:", scheme: "ms-outlook", category: .communication, bundleID: "com.microsoft.Office.Outlook"),
        CatalogApp(slug: "gmail", displayName: "Gmail", urlString: "googlegmail:", scheme: "googlegmail", category: .communication, bundleID: "com.google.Gmail"),
        CatalogApp(slug: "zoom", displayName: "Zoom", urlString: "zoomus:", scheme: "zoomus", category: .communication, bundleID: "us.zoom.videomeetings"),

        // MARK: apple basics (13)
        CatalogApp(slug: "maps", displayName: "Maps", urlString: "maps:", scheme: "maps", category: .apple, bundleID: "com.apple.Maps"),
        CatalogApp(slug: "music", displayName: "Music", urlString: "music:", scheme: "music", category: .apple, bundleID: "com.apple.Music"),
        CatalogApp(slug: "photos", displayName: "Photos", urlString: "photos-redirect:", scheme: "photos-redirect", category: .apple, bundleID: "com.apple.mobileslideshow"),
        CatalogApp(slug: "calendar", displayName: "Calendar", urlString: "calshow:", scheme: "calshow", category: .apple, bundleID: "com.apple.mobilecal"),
        CatalogApp(slug: "notes", displayName: "Notes", urlString: "mobilenotes:", scheme: "mobilenotes", category: .apple, bundleID: "com.apple.mobilenotes"),
        CatalogApp(slug: "shortcuts", displayName: "Shortcuts", urlString: "shortcuts:", scheme: "shortcuts", category: .apple, bundleID: "com.apple.shortcuts"),
        CatalogApp(slug: "reminders", displayName: "Reminders", urlString: "x-apple-reminderkit:", scheme: "x-apple-reminderkit", category: .apple, bundleID: "com.apple.reminders"),
        CatalogApp(slug: "files", displayName: "Files", urlString: "shareddocuments:", scheme: "shareddocuments", category: .apple, bundleID: "com.apple.DocumentsApp"),
        CatalogApp(slug: "books", displayName: "Books", urlString: "ibooks:", scheme: "ibooks", category: .apple, bundleID: "com.apple.iBooks"),
        CatalogApp(slug: "podcasts", displayName: "Podcasts", urlString: "podcasts:", scheme: "podcasts", category: .apple, bundleID: "com.apple.podcasts"),
        CatalogApp(slug: "wallet", displayName: "Wallet", urlString: "shoebox:", scheme: "shoebox", category: .apple, bundleID: "com.apple.Passbook"),
        CatalogApp(slug: "health", displayName: "Health", urlString: "x-apple-health:", scheme: "x-apple-health", category: .apple, bundleID: "com.apple.Health"),
        CatalogApp(slug: "weather", displayName: "Weather", urlString: "weather:", scheme: "weather", category: .apple, bundleID: "com.apple.weather"),

        // MARK: media (7)
        CatalogApp(slug: "spotify", displayName: "Spotify", urlString: "spotify:", scheme: "spotify", category: .media, bundleID: "com.spotify.client"),
        CatalogApp(slug: "youtube", displayName: "YouTube", urlString: "youtube:", scheme: "youtube", category: .media, bundleID: "com.google.ios.youtube"),
        CatalogApp(slug: "netflix", displayName: "Netflix", urlString: "nflx:", scheme: "nflx", category: .media, bundleID: "com.netflix.Netflix"),
        CatalogApp(slug: "twitch", displayName: "Twitch", urlString: "twitch:", scheme: "twitch", category: .media, bundleID: "tv.twitch"),
        CatalogApp(slug: "overcast", displayName: "Overcast", urlString: "overcast:", scheme: "overcast", category: .media, bundleID: "fm.overcast.overcast"),
        CatalogApp(slug: "pocketcasts", displayName: "Pocket Casts", urlString: "pktc:", scheme: "pktc", category: .media, bundleID: "au.com.shiftyjelly.podcasts"),
        CatalogApp(slug: "audible", displayName: "Audible", urlString: "audible:", scheme: "audible", category: .media, bundleID: "com.audible.iphone"),

        // MARK: social (9)
        CatalogApp(slug: "instagram", displayName: "Instagram", urlString: "instagram:", scheme: "instagram", category: .social, bundleID: "com.burbn.instagram"),
        CatalogApp(slug: "x", displayName: "X", urlString: "twitter:", scheme: "twitter", category: .social, bundleID: "com.atebits.Tweetie2"),
        CatalogApp(slug: "facebook", displayName: "Facebook", urlString: "fb:", scheme: "fb", category: .social, bundleID: "com.facebook.Facebook"),
        CatalogApp(slug: "snapchat", displayName: "Snapchat", urlString: "snapchat:", scheme: "snapchat", category: .social, bundleID: "com.toyopagroup.picaboo"),
        CatalogApp(slug: "tiktok", displayName: "TikTok", urlString: "tiktok:", scheme: "tiktok", category: .social, bundleID: "com.zhiliaoapp.musically"),
        CatalogApp(slug: "reddit", displayName: "Reddit", urlString: "reddit:", scheme: "reddit", category: .social, bundleID: "com.reddit.Reddit"),
        CatalogApp(slug: "pinterest", displayName: "Pinterest", urlString: "pinterest:", scheme: "pinterest", category: .social, bundleID: "pinterest"),
        CatalogApp(slug: "linkedin", displayName: "LinkedIn", urlString: "linkedin:", scheme: "linkedin", category: .social, bundleID: "com.linkedin.LinkedIn"),
        CatalogApp(slug: "threads", displayName: "Threads", urlString: "threads:", scheme: "threads", category: .social, bundleID: "com.burbn.barcelona"),

        // MARK: getting around (4)
        CatalogApp(slug: "uber", displayName: "Uber", urlString: "uber:", scheme: "uber", category: .gettingAround, bundleID: "com.ubercab.UberClient"),
        CatalogApp(slug: "lyft", displayName: "Lyft", urlString: "lyft:", scheme: "lyft", category: .gettingAround, bundleID: "com.zimride.instant"),
        CatalogApp(slug: "waze", displayName: "Waze", urlString: "waze:", scheme: "waze", category: .gettingAround, bundleID: "com.waze.iphone"),
        CatalogApp(slug: "googlemaps", displayName: "Google Maps", urlString: "comgooglemaps:", scheme: "comgooglemaps", category: .gettingAround, bundleID: "com.google.Maps"),

        // MARK: money (4)
        CatalogApp(slug: "venmo", displayName: "Venmo", urlString: "venmo:", scheme: "venmo", category: .money, bundleID: "net.kortina.labs.Venmo"),
        CatalogApp(slug: "paypal", displayName: "PayPal", urlString: "paypal:", scheme: "paypal", category: .money, bundleID: "com.yourcompany.PPClient"),
        CatalogApp(slug: "cashapp", displayName: "Cash App", urlString: "squarecash:", scheme: "squarecash", category: .money, bundleID: "com.squareup.cash"),
        CatalogApp(slug: "robinhood", displayName: "Robinhood", urlString: "robinhood:", scheme: "robinhood", category: .money, bundleID: "com.robinhood.release.Robinhood"),

        // MARK: mind & body (3)
        CatalogApp(slug: "strava", displayName: "Strava", urlString: "strava:", scheme: "strava", category: .mindBody, bundleID: "com.strava.stravaride"),
        CatalogApp(slug: "headspace", displayName: "Headspace", urlString: "headspace:", scheme: "headspace", category: .mindBody, bundleID: "com.getsomeheadspace.headspace"),
        CatalogApp(slug: "duolingo", displayName: "Duolingo", urlString: "duolingo:", scheme: "duolingo", category: .mindBody, bundleID: "com.duolingo.DuolingoMobile"),

        // MARK: tools (7)
        CatalogApp(slug: "chrome", displayName: "Chrome", urlString: "googlechrome:", scheme: "googlechrome", category: .tools, bundleID: "com.google.chrome.ios"),
        CatalogApp(slug: "notion", displayName: "Notion", urlString: "notion:", scheme: "notion", category: .tools, bundleID: "notion.id"),
        CatalogApp(slug: "things", displayName: "Things", urlString: "things:", scheme: "things", category: .tools, bundleID: "com.culturedcode.ThingsiPhone"),
        CatalogApp(slug: "todoist", displayName: "Todoist", urlString: "todoist:", scheme: "todoist", category: .tools, bundleID: "com.todoist.ios"),
        CatalogApp(slug: "obsidian", displayName: "Obsidian", urlString: "obsidian:", scheme: "obsidian", category: .tools, bundleID: "md.obsidian"),
        CatalogApp(slug: "chatgpt", displayName: "ChatGPT", urlString: "chatgpt:", scheme: "chatgpt", category: .tools, bundleID: "com.openai.chat"),
        CatalogApp(slug: "amazon", displayName: "Amazon", urlString: "com.amazon.mobile.shopping:", scheme: "com.amazon.mobile.shopping", category: .tools, bundleID: "com.amazon.Amazon"),
    ]

    static func app(slug: String) -> CatalogApp? {
        all.first { $0.slug == slug }
    }

    static func apps(in category: CatalogCategory) -> [CatalogApp] {
        all.filter { $0.category == category }
    }
}
