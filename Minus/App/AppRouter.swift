import SwiftUI

/// Navigation shape: single stack, Home at root, everything else pushed.
enum Route: Hashable {
    case focus
    case awareness
    case settings
    case schedules
    case scheduleEditor(id: UUID?)
    case settingsIntention
    case settingsEssentials
    case settingsCard(id: UUID?)
    case settingsCustom(cardID: UUID?, term: String = "")
    case settingsBlocked
    case settingsStrictness
    case settingsPermission
    case settingsAbout
    case settingsGuide
}

@MainActor
@Observable
final class AppRouter {
    var path: [Route] = []

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    #if DEBUG
    /// MINUS_SCREEN deep-jump for screenshot tours (focus | awareness |
    /// settings | schedules | settings-{sub}).
    func jumpFromEnvironment() {
        switch ProcessInfo.processInfo.environment["MINUS_SCREEN"] {
        case "focus": path = [.focus]
        case "awareness": path = [.awareness]
        case "settings": path = [.settings]
        case "schedules": path = [.focus, .schedules]
        case "settings-cards": path = [.settings, .settingsEssentials]
        case "settings-card-detail": path = [.settings, .settingsEssentials, .settingsCard(id: nil)]
        // Depth capped at 3 — NavigationStack drops deeper one-shot pushes.
        case "settings-custom": path = [.settings, .settingsEssentials, .settingsCustom(cardID: nil, term: "")]
        case "settings-blocked": path = [.settings, .settingsBlocked]
        case "settings-permission": path = [.settings, .settingsPermission]
        case "settings-strictness": path = [.settings, .settingsStrictness]
        case "settings-about": path = [.settings, .settingsAbout]
        case "settings-guide": path = [.settings, .settingsGuide]
        default: break
        }
    }
    #endif
}
