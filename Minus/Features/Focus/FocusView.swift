import FamilyControls
import SwiftData
import SwiftUI

/// Focus: pick a duration, start a session. Renders exactly one of four
/// states — active session, permission denied, no blocklist, or the idle
/// duration picker. States swap on the signature curve.
struct FocusView: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(AppRouter.self) private var router
    @Query private var blockLists: [BlockList]

    @State private var selectedMinutes: Int?
    @State private var customActive = false
    @State private var customText = ""
    @State private var startError: String?
    /// Picking blocked apps from here, rather than sending the user to
    /// Settings to find the same picker. Always a fresh flag-true selection:
    /// includeEntireCategory is init-only, and a decoded flag-false one
    /// silently reverts the B1 count fix.
    @State private var liveSelection = FamilyActivitySelection(includeEntireCategory: true)
    @State private var pickerPresented = false

    private static let presets = [15, 30, 60, 120]

    private var defaultBlockList: BlockList? {
        blockLists.first { $0.isDefault }
    }

    private var hasSelection: Bool {
        defaultBlockList?.selectionData != nil
    }

    private var customMinutes: Int? {
        Int(customText)
    }

    private var chosenMinutes: Int? {
        customActive ? customMinutes : selectedMinutes
    }

    private var customTooShort: Bool {
        customActive && !customText.isEmpty && (customMinutes ?? 0) < ScheduleMath.minimumWindowMinutes
    }

    private var canStart: Bool {
        guard let minutes = chosenMinutes else { return false }
        return minutes >= ScheduleMath.minimumWindowMinutes
    }

    var body: some View {
        ZStack {
            MN.obsidian.ignoresSafeArea()
            content
                .animation(MMotion.signature, value: deps.coordinator.isSessionActive)
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            // The active void has no header row, so the glyph overlays there —
            // at the SAME insets as PushedHeader's glyph (F-C: one position,
            // one transition; no jump, no double glyph). Leaving is not
            // ending — Home keeps showing the countdown line.
            Group {
                if deps.coordinator.isSessionActive {
                    BackGlyph()
                        .padding(.leading, MN.Space.m)
                        .padding(.top, MN.Space.xxs)
                        .transition(.opacity)
                }
            }
        }
        // Attached here, not inside `content`: the picker is a remote view
        // service, and an anchor that comes and goes with a branch renders it
        // blank (the v1.1 lesson, same as BlockListEditView).
        .familyActivityPicker(isPresented: $pickerPresented, selection: $liveSelection)
        .onChange(of: pickerPresented) { _, presented in
            guard !presented, !deps.service.isMock else { return }
            deps.commitBlockSelection(liveSelection)
            // hasSelection flips, so `content` re-renders as the duration
            // picker on its own. No push, no back-tracking: the user lands
            // exactly where they were trying to get.
        }
    }

    @ViewBuilder
    private var content: some View {
        if deps.coordinator.isSessionActive {
            ActiveSessionView()
                .transition(.opacity)
        } else if deps.service.authorizationStatus == .denied {
            deniedState
        } else if !hasSelection {
            noBlockListState
        } else {
            idlePicker
        }
    }

    // MARK: Idle — the duration picker

    private var idlePicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            PushedHeader(eyebrow: "FOCUS")

            Text("How long?")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)
                .padding(.top, MN.Space.l)

            VStack(spacing: 0) {
                ForEach(Self.presets, id: \.self) { minutes in
                    OnboardingSelectRow(
                        title: minutes >= 60 ? "\(minutes / 60) hour\(minutes >= 120 ? "s" : "")" : "\(minutes) minutes",
                        isSelected: !customActive && selectedMinutes == minutes,
                        accessibilityID: "row-duration-\(minutes)"
                    ) {
                        customActive = false
                        selectedMinutes = minutes
                        startError = nil
                    }
                }
                OnboardingSelectRow(
                    title: "custom…",
                    isSelected: customActive,
                    accessibilityID: "row-duration-custom"
                ) {
                    customActive = true
                    startError = nil
                }
            }
            .padding(.top, MN.Space.m)

            if customActive {
                FieldShell(placeholder: "minutes (15 or more)", text: $customText, accessibilityID: "field-custom-minutes")
                    .padding(.top, MN.Space.s)
                    .onChange(of: customText) { _, value in
                        customText = String(value.filter(\.isNumber).prefix(3))
                    }
                if customTooShort {
                    Text("at least 15 minutes")
                        .mnType(.caption)
                        .foregroundStyle(MN.fogBlue)
                        .padding(.top, MN.Space.xs)
                        .accessibilityIdentifier("custom-too-short")
                }
            }

            if let startError {
                Text(startError)
                    .mnType(.caption)
                    .foregroundStyle(MN.fogBlue)
                    .padding(.top, MN.Space.s)
                    .accessibilityIdentifier("start-error")
            }

            Spacer(minLength: MN.Space.l)

            OutlinedCTA(title: "Start session", prominent: true) {
                start()
            }
            .disabled(!canStart)
            .opacity(canStart ? 1 : 0.35)
            .accessibilityIdentifier("cta-start")

            GhostCaptionButton(title: "Schedules", accessibilityID: "nav-schedules") {
                router.push(.schedules)
            }
            .padding(.top, MN.Space.xs)
            .padding(.bottom, MN.Space.m)
        }
        .padding(.horizontal, MN.Space.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focus-idle")
    }

    private func start() {
        guard let minutes = chosenMinutes, let blockList = defaultBlockList else { return }
        do {
            try deps.coordinator.start(minutes: minutes, blockList: blockList)
            startError = nil
        } catch {
            startError = "couldn't start. try again"
        }
    }

    // MARK: Denied

    private var deniedState: some View {
        VStack(alignment: .leading, spacing: 0) {
            PushedHeader(eyebrow: "FOCUS")
            Text("Screen time is off.")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)
                .padding(.top, MN.Space.l)
            Text("minus can't shield apps without Screen Time access. Grant it in settings and focus comes back.")
                .mnType(.body)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)
                .padding(.top, MN.Space.s)
            Spacer()
            OutlinedCTA(title: "Open settings", prominent: true) {
                router.push(.settings)
            }
            .padding(.bottom, MN.Space.m)
        }
        .padding(.horizontal, MN.Space.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focus-denied")
    }

    // MARK: No blocklist

    private var noBlockListState: some View {
        VStack(alignment: .leading, spacing: 0) {
            PushedHeader(eyebrow: "FOCUS")
            Text("Nothing to block yet.")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)
                .padding(.top, MN.Space.l)
            Text("choose the apps that lose their place during focus.")
                .mnType(.body)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)
                .padding(.top, MN.Space.s)
            Spacer()
            OutlinedCTA(title: "Choose apps", prominent: true) {
                // The simulator has no Screen Time picker, so the mock build
                // keeps navigating — but to the blocked-apps screen, not the
                // settings root it used to dump the user on.
                if deps.service.isMock {
                    router.push(.settingsBlocked)
                } else {
                    pickerPresented = true
                }
            }
            .accessibilityIdentifier("cta-choose-blocked")
            .padding(.bottom, MN.Space.m)
        }
        .padding(.horizontal, MN.Space.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focus-empty-blocklist")
    }

}

