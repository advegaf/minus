import SwiftUI

/// The one permission, asked honestly. minus uses Apple's Screen Time to shield
/// apps during a session; nothing leaves the device, and shields are Apple's,
/// not unbreakable. The footer follows the authorization state: ask → request →
/// granted (auto-advance) or denied (retry, or carry on without shields).
struct PermissionStep: View {
    @Environment(AppDependencies.self) private var deps
    let advance: () -> Void

    @State private var inFlight = false
    @State private var pulse = false

    private var status: ScreenTimeAuthStatus { deps.service.authorizationStatus }

    var body: some View {
        VStack(alignment: .leading, spacing: MN.Space.m) {
            Text("One permission.")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)

            if deps.service.isMock {
                PillTag("SIMULATOR MOCK")
            }

            Text("minus uses Apple's Screen Time to shield the apps you choose while a session runs. Nothing leaves this device.")
                .mnType(.body)
                .foregroundStyle(MN.boneWhite)
                .frame(maxWidth: 330, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if status == .denied {
                Text("You can grant it later in Settings. focus sessions won't shield until then.")
                    .mnType(.body)
                    .foregroundStyle(MN.fogBlue)
                    .frame(maxWidth: 330, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("copy-denied")
                    .transition(.opacity)
            }

            Spacer(minLength: MN.Space.l)

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(MMotion.signature, value: status)
        .task(id: status) { scheduleAdvanceIfApproved() }
    }

    // MARK: Footer states

    @ViewBuilder
    private var footer: some View {
        if inFlight {
            // Non-interactive breath while the system sheet is up.
            Text("REQUESTING\u{2026}")
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: .infinity, minHeight: MN.minHit)
                .opacity(pulse ? 0.35 : 1)
                .accessibilityIdentifier("state-requesting")
                .onAppear {
                    pulse = false
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
        } else {
            switch status {
            case .notDetermined:
                OutlinedCTA(title: "ALLOW SCREEN TIME", prominent: true, action: request)
                    .accessibilityIdentifier("cta-allow")

            case .denied:
                VStack(spacing: MN.Space.s) {
                    OutlinedCTA(title: "TRY AGAIN", prominent: true, action: request)
                        .accessibilityIdentifier("cta-try-again")
                    GhostCaptionButton(
                        title: "SKIP FOR NOW",
                        accessibilityID: "cta-skip-permission",
                        action: advance
                    )
                }

            case .approved:
                // Held for a 0.6s beat by scheduleAdvanceIfApproved().
                Text("GRANTED")
                    .mnType(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(MN.fogBlue)
                    .frame(maxWidth: .infinity, minHeight: MN.minHit)
                    .accessibilityIdentifier("state-granted")
            }
        }
    }

    // MARK: Actions

    private func request() {
        inFlight = true
        Task { @MainActor in
            let result = await deps.service.requestAuthorization()
            inFlight = false
            // Own the whole path here so the grant reliably lands even though
            // the status flips mid-request; the 0.6s beat lets "GRANTED" read.
            if result == .approved {
                try? await Task.sleep(for: .milliseconds(600))
                advance()
            }
        }
    }

    /// Covers the rare case of arriving already-approved: the request() path
    /// handles every tap-driven grant itself.
    private func scheduleAdvanceIfApproved() {
        guard status == .approved, !inFlight else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard status == .approved, !inFlight else { return }
            advance()
        }
    }
}
