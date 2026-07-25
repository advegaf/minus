import SwiftData
import SwiftUI

/// Settings root: quiet rows in the selection-row vocabulary, each pushing a
/// focused subscreen. Reset lives at the bottom as a ghost — destructive
/// gravity without a drop of red.
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
                        row("strictness", detail: config?.strictness.rawValue, id: "row-strictness") {
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

                    GhostCaptionButton(title: "Reset everything", accessibilityID: "cta-reset") {
                        confirmingReset = true
                    }
                    .padding(.top, MN.Space.section)
                    .padding(.bottom, MN.Space.l)
                }
                .padding(.horizontal, MN.Space.m)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Reset everything? Sessions, schedules, essentials, and your intention all go.",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { resetAll() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings")
    }

    @State private var confirmingReset = false

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

    private func resetAll() {
        deps.coordinator.resetAll()
        for schedule in (try? deps.context.fetch(FetchDescriptor<FocusSchedule>())) ?? [] {
            deps.context.delete(schedule)
        }
        for session in (try? deps.context.fetch(FetchDescriptor<FocusSession>())) ?? [] {
            deps.context.delete(session)
        }
        for app in (try? deps.context.fetch(FetchDescriptor<EssentialApp>())) ?? [] {
            deps.context.delete(app)
        }
        for card in (try? deps.context.fetch(FetchDescriptor<LauncherCard>())) ?? [] {
            deps.context.delete(card)
        }
        for list in (try? deps.context.fetch(FetchDescriptor<BlockList>())) ?? [] {
            deps.context.delete(list)
        }
        for config in configs {
            deps.context.delete(config)
        }
        try? deps.context.save()
        router.popToRoot()
    }
}
