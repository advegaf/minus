import Foundation

/// The minus:// vocabulary — two routes, parsed pure.
enum DeepLink: Equatable, Sendable {
    /// minus://open/{slug} — trampoline to an essential app.
    case openEssential(slug: String)
    /// minus://focus — land on the Focus screen.
    case focus

    static func parse(_ url: URL) -> DeepLink? {
        guard url.scheme == "minus" else { return nil }
        switch url.host() {
        case "focus":
            return .focus
        case "open":
            let slug = url.pathComponents.dropFirst().first ?? ""
            return slug.isEmpty ? nil : .openEssential(slug: slug)
        default:
            return nil
        }
    }
}
