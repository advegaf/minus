import FamilyControls
import SwiftUI

/// The last step: what a focus session shields. On device this is Apple's own
/// FamilyActivityPicker (opaque tokens, chosen by the user); in the simulator,
/// where the picker can't run, a curated list of the usual suspects stands in so
/// every state stays screenshot-able. Finishing stamps the onboarding gate and
/// the app root swaps this whole flow out for Home.
struct BlockedStep: View {
    @Environment(AppDependencies.self) private var deps

    // Mock (simulator) state.
    @State private var selectedMock: [String] = []
    @State private var appeared = false

    // Live (device) state.
    // includeEntireCategory: picking a category materializes its member apps
    // into applicationTokens, so counts read the way users expect (B1). The
    // flag is init-only — never reuse a decoded selection as a picker binding.
    @State private var liveSelection = FamilyActivitySelection(includeEntireCategory: true)
    @State private var pickerPresented = false

    /// The simulator stand-in: distracting apps only, never the essentials.
    private let distractions: [(slug: String, name: String)] = [
        ("instagram", "Instagram"),
        ("tiktok", "TikTok"),
        ("x", "X"),
        ("youtube", "YouTube"),
        ("reddit", "Reddit"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: MN.Space.m) {
            Text("What gets blocked?")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)

            Text("the apps that pull you under. shields lift the moment a session ends.")
                .mnType(.body)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 330, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if deps.service.isMock {
                mockList
            } else {
                liveChooser
                Spacer(minLength: MN.Space.l)
            }

            if let summary = summaryText {
                Text(summary)
                    .mnType(.caption)
                    .foregroundStyle(MN.fogBlue)
                    .transition(.opacity)
            }

            VStack(spacing: MN.Space.s) {
                OutlinedCTA(title: "ENTER MINUS", prominent: true) {
                    finish(writeSelection: hasSelection)
                }
                .accessibilityIdentifier("cta-finish")

                GhostCaptionButton(
                    title: "SKIP",
                    accessibilityID: "cta-skip-blocked",
                    action: { finish(writeSelection: false) }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(MMotion.micro, value: summaryText)
        .onAppear { appeared = true }
    }

    // MARK: Mock list (simulator)

    private var mockList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(distractions.enumerated()), id: \.element.slug) { index, item in
                    OnboardingSelectRow(
                        title: item.name,
                        isSelected: selectedMock.contains(item.slug),
                        accessibilityID: "row-\(item.slug)",
                        action: { toggleMock(item.slug) }
                    )
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(
                        MMotion.micro.delay(Double(index) * MMotion.staggerStep),
                        value: appeared
                    )
                }
            }
        }
    }

    // MARK: Live chooser (device)

    private var liveChooser: some View {
        OutlinedCTA(title: "CHOOSE APPS", prominent: true) {
            pickerPresented = true
        }
        .accessibilityIdentifier("cta-choose-apps")
        .familyActivityPicker(isPresented: $pickerPresented, selection: $liveSelection)
    }

    // MARK: State

    private var hasSelection: Bool {
        if deps.service.isMock {
            return !selectedMock.isEmpty
        }
        return !liveSelection.applicationTokens.isEmpty || !liveSelection.categoryTokens.isEmpty
    }

    /// Fog summary line: the mock always claims two categories; the live path
    /// reads the real counts back out of the encoded selection.
    private var summaryText: String? {
        if deps.service.isMock {
            guard !selectedMock.isEmpty else { return nil }
            return SelectionSummaryText.line(apps: selectedMock.count, categories: 2)
        }
        let summary = deps.service.selectionSummary(from: LiveScreenTimeService.encodeSelection(liveSelection))
        guard summary.apps + summary.categories > 0 else { return nil }
        return SelectionSummaryText.line(apps: summary.apps, categories: summary.categories)
    }

    private func toggleMock(_ slug: String) {
        if let idx = selectedMock.firstIndex(of: slug) {
            selectedMock.remove(at: idx)
        } else {
            selectedMock.append(slug)
        }
    }

    private func encodedSelection() -> Data? {
        if deps.service.isMock {
            return MockScreenTimeService.encodeSelection(apps: selectedMock.count, categories: 2)
        }
        return LiveScreenTimeService.encodeSelection(liveSelection)
    }

    // MARK: Finish

    private func finish(writeSelection: Bool) {
        let context = deps.context
        if writeSelection {
            let blockList = MinusContainer.defaultBlockList(in: context)
            blockList.selectionData = encodedSelection()
            blockList.updatedAt = ClockProvider.now()
        }
        let config = MinusContainer.userConfig(in: context)
        config.onboardedAt = ClockProvider.now()
        try? context.save()
    }
}
