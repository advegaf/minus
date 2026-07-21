import SwiftData
import SwiftUI

/// The focused void — the app's hero state. Centered composition (the one
/// screen that abandons the leading margin): prism above, monumental countdown,
/// the intention as a quiet anchor, and an exit whose friction matches the
/// user's chosen strictness.
struct ActiveSessionView: View {
    @Environment(AppDependencies.self) private var deps
    @Query private var configs: [UserConfig]

    private var strictness: Strictness {
        configs.first { $0.id == UserConfig.wellKnownID }?.strictness ?? .normal
    }

    private var intention: String {
        configs.first { $0.id == UserConfig.wellKnownID }?.intentionText ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: MN.Space.xl)

            PrismArtifact(size: 180)

            TimelineView(.periodic(from: .now, by: 1)) { _ in
                countdown
            }
            .padding(.top, MN.Space.xl)

            if !intention.isEmpty {
                Text(intention)
                    .mnType(.body)
                    .foregroundStyle(MN.fogBlue)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .padding(.top, MN.Space.m)
            }

            Spacer(minLength: MN.Space.l)

            endControl
                .padding(.bottom, MN.Space.m)
        }
        .padding(.horizontal, MN.Space.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("active-session")
    }

    // MARK: Countdown

    private var remainingText: String {
        let remaining = max(0, deps.coordinator.remaining ?? 0)
        let total = Int(remaining.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var countdown: some View {
        FixedDigits(text: remainingText, token: .displaySm, slot: DigitMetrics.displaySmSlot)
            .accessibilityIdentifier("session-countdown")
    }

    // MARK: Exit per strictness

    /// One fixed-height slot for all three strictness modes, so the countdown
    /// above never shifts when strictness changes.
    @ViewBuilder
    private var endControl: some View {
        Group {
            switch strictness {
            case .normal:
                OutlinedCTA(title: "End session", prominent: true) {
                    deps.coordinator.endEarly()
                }
                .accessibilityIdentifier("cta-end")
            case .friction:
                HoldToEndControl {
                    deps.coordinator.endEarly()
                }
            case .strict:
                Text("ends at \(endTimeText)")
                    .mnType(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(MN.fogBlue)
                    .accessibilityIdentifier("strict-note")
            }
        }
        .frame(height: 52)
    }

    private var endTimeText: String {
        guard let end = deps.coordinator.activeSnapshot?.plannedEndAt else { return "—" }
        let c = Calendar.current
        return String(format: "%02d:%02d", c.component(.hour, from: end), c.component(.minute, from: end))
    }
}

/// Deliberate exit: pressing fills the frame over two slow linear seconds;
/// letting go snaps back fast (slow where the user decides, fast where the
/// system responds). Completing the hold ends the session.
struct HoldToEndControl: View {
    let complete: () -> Void

    @State private var pressing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("hold to end")
            .mnType(.caption)
            .textCase(.uppercase)
            .foregroundStyle(MN.boneWhite)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(MN.boneWhite.opacity(0.18))
                        .frame(width: pressing ? proxy.size.width : 0)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: MN.Radius.nav)
                    .strokeBorder(MN.boneWhite, lineWidth: MN.hairline)
            )
            .clipShape(RoundedRectangle(cornerRadius: MN.Radius.nav))
            .contentShape(Rectangle())
            .scaleEffect(pressing ? 0.97 : 1)
            .onLongPressGesture(minimumDuration: 2.0) {
                complete()
            } onPressingChanged: { isPressing in
                if reduceMotion {
                    pressing = isPressing
                } else if isPressing {
                    withAnimation(.linear(duration: 2.0)) { pressing = true }
                } else {
                    withAnimation(MMotion.exit) { pressing = false }
                }
            }
            .accessibilityIdentifier("cta-hold-end")
    }
}
