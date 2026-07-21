import SwiftUI

/// The five-step first run: welcome → intention → essentials → permission →
/// blocked, then the onboarding gate lifts and the app shell takes over. Steps
/// are a `@State` enum; each swap is the signature optical-focus pull (opacity +
/// a ~12pt upward settle entering, a faster fade leaving). A fog eyebrow names
/// the current step top-left — the only progress indicator, by design.
struct OnboardingFlow: View {
    @State private var step: Step

    init() {
        var initial = Step.welcome
        #if DEBUG
        // Deterministic per-step screenshots: MINUS_ONBOARDING_STEP=intention etc.
        if let raw = ProcessInfo.processInfo.environment["MINUS_ONBOARDING_STEP"],
           let jumped = Step(rawValue: raw) {
            initial = jumped
        }
        #endif
        _step = State(initialValue: initial)
    }

    var body: some View {
        ZStack {
            MN.obsidian.ignoresSafeArea()

            VStack(alignment: .leading, spacing: MN.Space.l) {
                // The one progress indicator: a quiet fog label, top-left,
                // cross-fading as the step changes. No dots, no bar.
                Text(step.eyebrow)
                    .mnType(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(MN.fogBlue)
                    .contentTransition(.opacity)
                    .padding(.top, MN.Space.s)

                ZStack(alignment: .topLeading) {
                    Color.clear
                    stepView(for: step)
                        .id(step)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier(step.containerID)
                        .transition(stepTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, MN.Space.m)
            .padding(.bottom, MN.Space.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: Steps

    @ViewBuilder
    private func stepView(for step: Step) -> some View {
        switch step {
        case .welcome:
            WelcomeStep(advance: { go(to: .intention) })
        case .intention:
            IntentionStep(advance: { go(to: .essentials) })
        case .essentials:
            EssentialsStep(advance: { go(to: .permission) })
        case .permission:
            PermissionStep(advance: { go(to: .blocked) })
        case .blocked:
            // Finishes onboarding by stamping onboardedAt; the app root's
            // @Query then swaps the whole flow out for Home.
            BlockedStep()
        }
    }

    private func go(to next: Step) {
        withAnimation(MMotion.signature) { step = next }
    }

    /// Enter on the signature curve (fade up 12pt); leave faster and subtler.
    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 12)).animation(MMotion.signature),
            removal: .opacity.animation(MMotion.exit)
        )
    }
}

// MARK: - Step model

extension OnboardingFlow {
    enum Step: String, CaseIterable {
        case welcome, intention, essentials, permission, blocked

        var eyebrow: String {
            switch self {
            case .welcome: "BEGIN"
            case .intention: "INTENTION"
            case .essentials: "ESSENTIALS"
            case .permission: "PERMISSION"
            case .blocked: "BLOCKED"
            }
        }

        var containerID: String { "step-\(rawValue)" }
    }
}

// MARK: - Shared onboarding parts

/// A list row where the colour *is* the state: selected names go bone-white with
/// a leading em-dash; unselected stay fog. No checkbox, no toggle. Dimmed rows
/// (a reached cap) fall to 0.35 and stop responding. Used by essentials and the
/// mock blocked list so both read as one gesture vocabulary.
struct OnboardingSelectRow: View {
    let title: String
    let isSelected: Bool
    /// True when a selection cap is reached and this row is not itself selected.
    var isDimmed: Bool = false
    let accessibilityID: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MN.Space.xs) {
                // Reserved marker column keeps every name on one optical line,
                // whether the dash is showing or not — no reflow on tap.
                Text("\u{2014}")
                    .mnType(.bodyLg)
                    .foregroundStyle(MN.boneWhite)
                    .opacity(isSelected ? 1 : 0)
                    .frame(width: MN.Space.m, alignment: .leading)

                Text(title)
                    .mnType(.bodyLg)
                    .foregroundStyle(isSelected ? MN.boneWhite : MN.fogBlue)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: MN.minHit, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(MN.ashBorder)
                    .frame(height: MN.hairline)
            }
        }
        .buttonStyle(.mnPress)
        .disabled(isDimmed)
        .opacity(isDimmed ? 0.35 : 1)
        .animation(MMotion.micro, value: isSelected)
        .animation(MMotion.micro, value: isDimmed)
        .accessibilityIdentifier(accessibilityID)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// A borderless fog caption that only reveals itself as tappable through the
/// universal 0.97 press — the quiet escape hatch (skip permission, skip blocked).
struct GhostCaptionButton: View {
    let title: String
    let accessibilityID: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: .infinity, minHeight: MN.minHit)
                .contentShape(Rectangle())
        }
        .buttonStyle(.mnPress)
        .accessibilityIdentifier(accessibilityID)
    }
}
