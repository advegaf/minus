import Foundation

/// The curated set of apps a user may keep on the Home list. FamilyActivity
/// tokens are opaque (no URL schemes), so essentials are our own catalog.
/// Every scheme here MUST also appear in LSApplicationQueriesSchemes
/// (project.yml) or canOpenURL lies — kept in lockstep by EssentialCatalogTests.
struct CatalogApp: Identifiable, Hashable, Sendable {
    var slug: String
    var displayName: String
    /// Full URL string handed to openURL (e.g. "sms:" or "spotify:").
    var urlString: String
    /// The bare scheme, for the LSApplicationQueriesSchemes lockstep test.
    var scheme: String

    var id: String { slug }
    var url: URL? { URL(string: urlString) }
}

enum EssentialAppCatalog {
    /// Max rows visible on Home — minimalism is the product.
    static let homeCap = 7

    static let all: [CatalogApp] = [
        CatalogApp(slug: "phone", displayName: "Phone", urlString: "tel:", scheme: "tel"),
        // messages:// lands on the conversation list; sms: opens a COMPOSE
        // sheet (T1 — the launcher must open apps, never start drafts).
        CatalogApp(slug: "messages", displayName: "Messages", urlString: "messages:", scheme: "messages"),
        CatalogApp(slug: "facetime", displayName: "FaceTime", urlString: "facetime:", scheme: "facetime"),
        // message:// opens the Mail inbox; mailto: composes.
        CatalogApp(slug: "mail", displayName: "Mail", urlString: "message:", scheme: "message"),
        CatalogApp(slug: "maps", displayName: "Maps", urlString: "maps:", scheme: "maps"),
        CatalogApp(slug: "music", displayName: "Music", urlString: "music:", scheme: "music"),
        CatalogApp(slug: "photos", displayName: "Photos", urlString: "photos-redirect:", scheme: "photos-redirect"),
        CatalogApp(slug: "calendar", displayName: "Calendar", urlString: "calshow:", scheme: "calshow"),
        CatalogApp(slug: "notes", displayName: "Notes", urlString: "mobilenotes:", scheme: "mobilenotes"),
        CatalogApp(slug: "shortcuts", displayName: "Shortcuts", urlString: "shortcuts:", scheme: "shortcuts"),
        CatalogApp(slug: "spotify", displayName: "Spotify", urlString: "spotify:", scheme: "spotify"),
        CatalogApp(slug: "whatsapp", displayName: "WhatsApp", urlString: "whatsapp:", scheme: "whatsapp"),
        CatalogApp(slug: "signal", displayName: "Signal", urlString: "sgnl:", scheme: "sgnl"),
        CatalogApp(slug: "telegram", displayName: "Telegram", urlString: "tg:", scheme: "tg"),
    ]

    static func app(slug: String) -> CatalogApp? {
        all.first { $0.slug == slug }
    }
}
