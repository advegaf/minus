import FamilyControls
import SwiftData
import SwiftUI

// MARK: - Intention

struct IntentionEditView: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(\.dismiss) private var dismiss
    @Query private var configs: [UserConfig]
    @State private var text = ""
    @State private var loaded = false

    /// v1.7: the goal is always saved; this governs only whether it renders.
    private var showsIntention: Bool {
        configs.first { $0.id == UserConfig.wellKnownID }?.showsIntention ?? true
    }

    var body: some View {
        SettingsShell(eyebrow: "INTENTION", id: "settings-intention", scrolls: true) {
            Text("What do you want back?")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)

            IntentionPresetRows(text: $text)
                .padding(.top, MN.Space.m)

            FieldShell(placeholder: "or write your own", text: $text, accessibilityID: "field-intention-edit")
                .padding(.top, MN.Space.m)
                .onChange(of: text) { _, value in
                    if value.count > 80 { text = String(value.prefix(80)) }
                }

            visibilitySection
                .padding(.top, MN.Space.xl)

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

    /// Selection rows, not a switch — the app has no toggles (brand rule),
    /// and these apply immediately like StrictnessView.
    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("VISIBILITY")
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.fogBlue)
                .padding(.bottom, MN.Space.xs)

            visibilityOption(
                title: "shown",
                note: "under the clock and on your widgets",
                value: true
            )
            visibilityOption(
                title: "hidden",
                note: "your goal stays saved, just not displayed",
                value: false
            )
        }
    }

    private func visibilityOption(title: String, note: String, value: Bool) -> some View {
        VStack(alignment: .leading, spacing: MN.Space.xxs) {
            OnboardingSelectRow(
                title: title,
                isSelected: showsIntention == value,
                accessibilityID: "intention-visibility-\(title)"
            ) {
                let config = MinusContainer.userConfig(in: deps.context)
                config.showsIntention = value
                try? deps.context.save()
            }
            Text(note)
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
                .padding(.bottom, MN.Space.s)
        }
    }
}

// MARK: - Essentials → CardsEditorViews.swift (v1.6)

// MARK: - Blocked apps

struct BlockListEditView: View {
    @Environment(AppDependencies.self) private var deps
    @State private var mockSelected: Set<String> = []
    @State private var loaded = false

    // Device re-pick (B2): the binding is ALWAYS a fresh flag-true selection
    // with token sets copied in — includeEntireCategory is init-only, and a
    // decoded flag-false selection would silently revert the B1 count fix.
    @State private var liveSelection = FamilyActivitySelection(includeEntireCategory: true)
    @State private var pickerPresented = false

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

    /// A running session freezes the list. Editing it mid-focus was a way
    /// straight through the shield: un-block an app and it opens, without
    /// ever passing the strictness gate that guards ending a session.
    private var isLocked: Bool { deps.coordinator.activeSnapshot != nil }

    var body: some View {
        SettingsShell(eyebrow: "BLOCKED", id: "settings-blocked", scrolls: true) {
            Text("What gets blocked?")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)

            if isLocked {
                locked
                    .padding(.top, MN.Space.m)
            } else {
                if isStale {
                    staleRecovery
                        .padding(.top, MN.Space.m)
                }

                if deps.service.isMock {
                    mockList
                        .padding(.top, MN.Space.m)
                } else {
                    deviceEditor
                        .padding(.top, MN.Space.m)
                }
            }
        }
        // Attached to the stable shell root, never inside a conditional branch:
        // the picker is a remote view service and re-evaluated anchors make it
        // render blank.
        .familyActivityPicker(isPresented: $pickerPresented, selection: $liveSelection)
        .onChange(of: pickerPresented) { _, presented in
            guard !presented, !deps.service.isMock else { return }
            deps.commitBlockSelection(liveSelection)
        }
        .onAppear(perform: seedLiveSelection)
    }

    private var locked: some View {
        VStack(alignment: .leading, spacing: MN.Space.s) {
            Text(SelectionSummaryText.line(
                apps: liveSummary.apps, categories: liveSummary.categories
            ))
            .mnType(.body)
            .foregroundStyle(MN.fogBlue)
            .accessibilityIdentifier("blocked-summary")

            Text("a session is running. this list stays put until it ends, or the shield would be one tap away from nothing.")
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)
                .accessibilityIdentifier("blocked-locked")
        }
    }

    // MARK: Device branch

    private var deviceEditor: some View {
        VStack(alignment: .leading, spacing: MN.Space.s) {
            Text(SelectionSummaryText.line(
                apps: liveSummary.apps, categories: liveSummary.categories
            ))
            .mnType(.body)
            .foregroundStyle(MN.fogBlue)
            .accessibilityIdentifier("blocked-summary")

            OutlinedCTA(title: "Re-pick apps", prominent: true) {
                pickerPresented = true
            }
            .accessibilityIdentifier("cta-repick")
        }
    }

    private var liveSummary: (apps: Int, categories: Int) {
        deps.service.selectionSummary(from: LiveScreenTimeService.encodeSelection(liveSelection))
    }

    private func seedLiveSelection() {
        guard !deps.service.isMock,
              let saved = LiveScreenTimeService.decodeSelection(blockList.selectionData) else { return }
        var fresh = FamilyActivitySelection(includeEntireCategory: true)
        fresh.applicationTokens = saved.applicationTokens
        fresh.categoryTokens = saved.categoryTokens
        fresh.webDomainTokens = saved.webDomainTokens
        liveSelection = fresh
    }

    private var staleRecovery: some View {
        VStack(alignment: .leading, spacing: MN.Space.xs) {
            Text("your blocked apps didn't survive a restore.")
                .mnType(.body)
                .foregroundStyle(MN.boneWhite)
            Text("re-pick them below. shields need fresh tokens.")
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
                    // Same propagation contract as the device path (SE-9).
                    deps.coordinator.refreshSchedules(blockList: blockList)
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

    /// A running session freezes the level. Loosening it mid-focus walked
    /// straight past the gate it exists to hold: pick strict, start, then
    /// pick normal, and END SESSION is back after all.
    private var isLocked: Bool { deps.coordinator.activeSnapshot != nil }

    var body: some View {
        SettingsShell(eyebrow: "STRICTNESS", id: "settings-strictness") {
            Text("How hard is quitting?")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)

            if isLocked {
                locked
                    .padding(.top, MN.Space.m)
            } else {
                VStack(spacing: 0) {
                    option(.normal, note: "end a session with one tap")
                    option(.friction, note: "hold for two seconds to end")
                    option(.strict, note: "no exit until the session completes")
                }
                .padding(.top, MN.Space.m)
            }

            Spacer()
        }
    }

    /// The level reads as plain text, not a row: nothing here should look
    /// like it takes a tap.
    private var locked: some View {
        VStack(alignment: .leading, spacing: MN.Space.s) {
            Text(current.rawValue)
                .mnType(.bodyLg)
                .foregroundStyle(MN.boneWhite)
                .accessibilityIdentifier("strictness-current")

            Text("a session is running. strictness stays put until it ends, or the gate would be one tap away from nothing.")
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)
                .accessibilityIdentifier("strictness-locked")
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

            Text("a phone that asks less of you. blocking runs on apple screen time. deleting the app always lifts every shield, and is the only way to start over.")
                .mnType(.body)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)
                .padding(.top, MN.Space.l)
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }

    private var body_: some View {
        VStack(alignment: .leading, spacing: 0) {
            PushedHeader(eyebrow: eyebrow)
                .padding(.bottom, MN.Space.l)

            content
        }
        .padding(.horizontal, MN.Space.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
