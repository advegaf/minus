import SwiftUI

/// The hero. A single prism glowing on the void, then the wordmark and the
/// promise, then one way forward. Everything is left-aligned to the eyebrow
/// column except the prism, which floats upper-centre in deliberate emptiness.
struct WelcomeStep: View {
    let advance: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: MN.Space.l)

            // The one chromatic element in the app, given room to breathe.
            HStack {
                Spacer(minLength: 0)
                PrismArtifact(size: 260)
                Spacer(minLength: 0)
            }

            Spacer(minLength: MN.Space.xl)

            VStack(alignment: .leading, spacing: MN.Space.s) {
                DisplayStack(lines: ["minus"], token: .displaySm)
                    .foregroundStyle(MN.boneWhite)

                Text("a phone that asks less of you.")
                    .mnType(.body)
                    .foregroundStyle(MN.boneWhite)
                    .frame(maxWidth: 300, alignment: .leading)
            }

            Spacer(minLength: MN.Space.l)

            OutlinedCTA(title: "BEGIN", prominent: true, action: advance)
                .accessibilityIdentifier("cta-begin")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
