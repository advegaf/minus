import SwiftData
import SwiftUI

/// Settings root: quiet rows in the selection-row vocabulary, each pushing a
/// focused subscreen. There is no reset: wiping everything from inside the app
/// was a loaded gun next to the shields, and deleting minus already lifts them
/// (About says so).
struct SettingsView: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(AppRouter.self) private var router
    @Query private var configs: [UserConfig]

    private var config: UserConfig? {
        configs.first { $0.id == UserConfig.wellKnownID }
    }

    private var permissionCaption: String {
        switch deps.service.authorizationStatus {
        case .approved: "on"
        case .denied: "off"
        case .notDetermined: "not set"
        }
    }

    var body: some View {
        ZStack {
            MN.obsidian.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PushedHeader(eyebrow: "SETTINGS")

                    VStack(spacing: 0) {
                        row("intention", detail: intentionDetail, id: "row-intention") {
                            router.push(.settingsIntention)
                        }
                        row("cards", detail: cardsDetail, id: "row-essentials") {
                            router.push(.settingsEssentials)
                        }
                        row("blocked apps", detail: blockedDetail, id: "row-blocked") {
                            router.push(.settingsBlocked)
                        }
                        row("strictness", detail: strictnessDetail, id: "row-strictness") {
                            router.push(.settingsStrictness)
                        }
                        row("screen time", detail: permissionCaption, id: "row-permission") {
                            router.push(.settingsPermission)
                        }
                        row("make it a dumb phone", detail: nil, id: "row-guide") {
                            router.push(.settingsGuide)
                        }
                        row("about", detail: nil, id: "row-about") {
                            router.push(.settingsAbout)
                        }
                    }
                    .padding(.top, MN.Space.l)

                    Spacer(minLength: MN.Space.section)
                }
                .padding(.horizontal, MN.Space.m)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings")
    }

    private var intentionDetail: String? {
        guard let config, !config.intentionText.isEmpty else { return "not set" }
        // v1.7: hidden is the louder fact — the text is still saved.
        return config.showsIntention ? config.intentionText : "hidden"
    }

    private var cardsDetail: String? {
        let count = MinusContainer.cards(in: deps.context).count
        guard count > 0 else { return nil }
        return count == 1 ? "1 card" : "\(count) cards"
    }

    /// While a session runs the list is frozen, and the row says so before
    /// the user makes the trip.
    private var blockedDetail: String? {
        if deps.coordinator.activeSnapshot != nil { return "locked while focused" }
        return blockedDetailText
    }

    /// Frozen for the same reason the blocklist is, and the row says so
    /// before the user makes the trip.
    private var strictnessDetail: String? {
        if deps.coordinator.activeSnapshot != nil { return "locked while focused" }
        return config?.strictness.rawValue
    }

    private var blockedDetailText: String? {
        let blockList = try? deps.context.fetch(
            FetchDescriptor<BlockList>(predicate: #Predicate { $0.isDefault })
        ).first
        guard let data = blockList?.selectionData else { return "nothing yet" }
        let summary = deps.service.selectionSummary(from: data)
        // Data present but nothing decodes = stale tokens (SE-4 contract).
        if summary.apps == 0 && summary.categories == 0 { return "needs re-pick" }
        return SelectionSummaryText.line(apps: summary.apps, categories: summary.categories)
    }

    private func row(_ title: String, detail: String?, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: MN.Space.s) {
                Text(title)
                    .mnType(.bodyLg)
                    .foregroundStyle(MN.boneWhite)
                Spacer(minLength: MN.Space.s)
                if let detail {
                    Text(detail.lowercased())
                        .mnType(.caption)
                        .foregroundStyle(MN.fogBlue)
                        .lineLimit(1)
                        .frame(maxWidth: 160, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity, minHeight: MN.minHit, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle().fill(MN.ashBorder).frame(height: MN.hairline)
            }
        }
        .buttonStyle(.mnPress)
        .accessibilityIdentifier(id)
    }
}
