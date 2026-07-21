import SwiftData
import SwiftUI

// MARK: - Intention

struct IntentionEditView: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var loaded = false

    var body: some View {
        SettingsShell(eyebrow: "INTENTION", id: "settings-intention") {
            Text("What do you want back?")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)

            FieldShell(placeholder: "your intention", text: $text, accessibilityID: "field-intention-edit")
                .padding(.top, MN.Space.l)
                .onChange(of: text) { _, value in
                    if value.count > 80 { text = String(value.prefix(80)) }
                }

            Spacer()

            OutlinedCTA(title: "Save", prominent: true) {
                let config = MinusContainer.userConfig(in: deps.context)
                config.intentionText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                try? deps.context.save()
                dismiss()
            }
            .accessibilityIdentifier("cta-save-intention")
            .padding(.bottom, MN.Space.m)
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            text = MinusContainer.userConfig(in: deps.context).intentionText
        }
    }
}

// MARK: - Essentials

struct EssentialsEditView: View {
    @Environment(AppDependencies.self) private var deps
    @Query(sort: \EssentialApp.sortOrder) private var chosen: [EssentialApp]

    private var chosenSlugs: Set<String> { Set(chosen.map(\.slug)) }
    private var atCap: Bool { chosen.count >= EssentialAppCatalog.homeCap }

    var body: some View {
        SettingsShell(eyebrow: "ESSENTIALS", id: "settings-essentials", scrolls: true) {
            Text("What stays?")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)
            Text("up to \(EssentialAppCatalog.homeCap) — order follows when you added them.")
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
                .padding(.top, MN.Space.xs)

            VStack(spacing: 0) {
                ForEach(EssentialAppCatalog.all) { app in
                    let isChosen = chosenSlugs.contains(app.slug)
                    OnboardingSelectRow(
                        title: app.displayName.lowercased(),
                        isSelected: isChosen,
                        isDimmed: !isChosen && atCap,
                        accessibilityID: "edit-row-\(app.slug)"
                    ) {
                        toggle(app, isChosen: isChosen)
                    }
                }
            }
            .padding(.top, MN.Space.m)
        }
    }

    private func toggle(_ app: CatalogApp, isChosen: Bool) {
        if isChosen {
            for row in chosen where row.slug == app.slug {
                deps.context.delete(row)
            }
        } else {
            guard !atCap else { return }
            let nextOrder = (chosen.map(\.sortOrder).max() ?? -1) + 1
            deps.context.insert(
                EssentialApp(slug: app.slug, displayName: app.displayName, urlScheme: app.urlString, sortOrder: nextOrder)
            )
        }
        try? deps.context.save()
    }
}

// MARK: - Blocked apps

struct BlockListEditView: View {
    @Environment(AppDependencies.self) private var deps
    @State private var mockSelected: Set<String> = []
    @State private var loaded = false

    private static let mockApps = ["instagram", "tiktok", "x", "youtube", "reddit", "twitch", "mail"]

    private var blockList: BlockList {
        MinusContainer.defaultBlockList(in: deps.context)
    }

    /// Data exists but decodes to nothing — the stale-token scenario.
    private var isStale: Bool {
        guard let data = blockList.selectionData, !data.isEmpty else { return false }
        let summary = deps.service.selectionSummary(from: data)
        return summary.apps == 0 && summary.categories == 0
    }

    var body: some View {
        SettingsShell(eyebrow: "BLOCKED", id: "settings-blocked", scrolls: true) {
            Text("What gets blocked?")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)

            if isStale {
                staleRecovery
                    .padding(.top, MN.Space.m)
            }

            if deps.service.isMock {
                mockList
                    .padding(.top, MN.Space.m)
            } else {
                Text("re-pick with Apple's picker on device.")
                    .mnType(.body)
                    .foregroundStyle(MN.fogBlue)
                    .padding(.top, MN.Space.m)
                // Device path presents FamilyActivityPicker from Focus/Onboarding
                // flows; Settings re-pick lands with the real picker in the
                // device pass (SE-3/SE-4 Needs device).
            }
        }
    }

    private var staleRecovery: some View {
        VStack(alignment: .leading, spacing: MN.Space.xs) {
            Text("your blocked apps didn't survive a restore.")
                .mnType(.body)
                .foregroundStyle(MN.boneWhite)
            Text("re-pick them below — shields need fresh tokens.")
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("stale-recovery")
    }

    private var mockList: some View {
        VStack(spacing: 0) {
            ForEach(Self.mockApps, id: \.self) { name in
                OnboardingSelectRow(
                    title: name,
                    isSelected: mockSelected.contains(name),
                    accessibilityID: "block-row-\(name)"
                ) {
                    if mockSelected.contains(name) {
                        mockSelected.remove(name)
                    } else {
                        mockSelected.insert(name)
                    }
                    blockList.selectionData = MockScreenTimeService.encodeSelection(
                        apps: mockSelected.count, categories: 2
                    )
                    blockList.updatedAt = ClockProvider.now()
                    try? deps.context.save()
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            let summary = deps.service.selectionSummary(from: blockList.selectionData)
            mockSelected = Set(Self.mockApps.prefix(summary.apps))
        }
    }
}

// MARK: - Strictness

struct StrictnessView: View {
    @Environment(AppDependencies.self) private var deps
    @Query private var configs: [UserConfig]

    private var current: Strictness {
        configs.first { $0.id == UserConfig.wellKnownID }?.strictness ?? .normal
    }

    var body: some View {
        SettingsShell(eyebrow: "STRICTNESS", id: "settings-strictness") {
            Text("How hard is quitting?")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)

            VStack(spacing: 0) {
                option(.normal, note: "end a session with one tap")
                option(.friction, note: "hold for two seconds to end")
                option(.strict, note: "no exit until the session completes")
            }
            .padding(.top, MN.Space.m)

            Spacer()
        }
    }

    private func option(_ level: Strictness, note: String) -> some View {
        VStack(alignment: .leading, spacing: MN.Space.xxs) {
            OnboardingSelectRow(
                title: level.rawValue,
                isSelected: current == level,
                accessibilityID: "strictness-\(level.rawValue)"
            ) {
                let config = MinusContainer.userConfig(in: deps.context)
                config.strictness = level
                try? deps.context.save()
            }
            Text(note)
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
                .padding(.bottom, MN.Space.s)
        }
    }
}

// MARK: - Permission

struct PermissionSettingsView: View {
    @Environment(AppDependencies.self) private var deps

    var body: some View {
        SettingsShell(eyebrow: "SCREEN TIME", id: "settings-permission") {
            Text(statusHeadline)
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)
                .accessibilityIdentifier("permission-status")

            Text("minus shields apps through Apple's Screen Time. nothing leaves the device.")
                .mnType(.body)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)
                .padding(.top, MN.Space.s)

            if deps.service.isMock {
                PillTag("Simulator")
                    .padding(.top, MN.Space.m)
            }

            Spacer()

            if deps.service.authorizationStatus != .approved {
                OutlinedCTA(title: "Grant access", prominent: true) {
                    Task { _ = await deps.service.requestAuthorization() }
                }
                .accessibilityIdentifier("cta-grant")

                GhostCaptionButton(title: "Open system settings", accessibilityID: "cta-system-settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .padding(.top, MN.Space.xs)
                .padding(.bottom, MN.Space.m)
            }
        }
    }

    private var statusHeadline: String {
        switch deps.service.authorizationStatus {
        case .approved: "Access is on."
        case .denied: "Access is off."
        case .notDetermined: "Not set up yet."
        }
    }
}

// MARK: - About

struct AboutView: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        SettingsShell(eyebrow: "ABOUT", id: "settings-about", scrolls: true) {
            DisplayStack(lines: ["minus"], token: .displaySm)
                .foregroundStyle(MN.boneWhite)

            Text("version \(version)")
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
                .padding(.top, MN.Space.s)
                .accessibilityIdentifier("about-version")

            Text("a phone that asks less of you. type set in General Sans (Fontshare). blocking by Apple Screen Time — deleting the app always lifts every shield.")
                .mnType(.body)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)
                .padding(.top, MN.Space.l)

            #if DEBUG
            Text("MONITOR LOG")
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.fogBlue)
                .padding(.top, MN.Space.section)
            let log = SharedState.monitorLog
            if log.isEmpty {
                Text("empty — the extension hasn't fired yet.")
                    .mnType(.caption)
                    .foregroundStyle(MN.fogBlue)
                    .padding(.top, MN.Space.xs)
            } else {
                VStack(alignment: .leading, spacing: MN.Space.xxs) {
                    ForEach(Array(log.suffix(30).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .mnType(.caption)
                            .foregroundStyle(MN.boneWhite)
                    }
                }
                .padding(.top, MN.Space.xs)
            }
            #endif
        }
    }
}

// MARK: - Shared shell

/// Common chrome for settings subscreens: obsidian void, fog eyebrow cleared
/// past the back glyph, single leading margin, optional scrolling.
struct SettingsShell<Content: View>: View {
    let eyebrow: String
    let id: String
    var scrolls: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            MN.obsidian.ignoresSafeArea()
            if scrolls {
                ScrollView { body_ }
            } else {
                body_
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { BackGlyph() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }

    private var body_: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow)
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.fogBlue)
                .padding(.top, MN.Space.s)
                .padding(.leading, MN.Space.xl)
                .padding(.bottom, MN.Space.l)

            content
        }
        .padding(.horizontal, MN.Space.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
