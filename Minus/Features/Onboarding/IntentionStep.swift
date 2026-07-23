import SwiftUI

/// One question, one line to answer it. The intention is stored the moment the
/// user continues and resurfaces later when a focus session gets hard. Continue
/// stays inert until there's something real to keep.
struct IntentionStep: View {
    @Environment(AppDependencies.self) private var deps
    let advance: () -> Void

    @State private var intention: String = ""

    /// Past this the quiet counter appears; at `hardCap` input stops.
    private let softCap = 60
    private let hardCap = 80

    private var trimmed: String {
        intention.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool { !trimmed.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: MN.Space.m) {
            Text("What do you want back?")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)
                .fixedSize(horizontal: false, vertical: true)

            Text("name the reason. it will be here when focus gets hard.")
                .mnType(.body)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            IntentionPresetRows(text: $intention)
                .padding(.top, MN.Space.xs)

            VStack(alignment: .trailing, spacing: MN.Space.xs) {
                FieldShell(
                    placeholder: "or write your own",
                    text: $intention,
                    accessibilityID: "field-intention"
                )
                .onChange(of: intention) { _, newValue in
                    if newValue.count > hardCap {
                        intention = String(newValue.prefix(hardCap))
                    }
                }

                if intention.count > softCap {
                    Text("\(intention.count) / \(hardCap)")
                        .mnType(.caption)
                        .foregroundStyle(MN.fogBlue)
                        .transition(.opacity)
                }
            }
            .animation(MMotion.micro, value: intention.count > softCap)

            Spacer(minLength: MN.Space.l)

            OutlinedCTA(title: "CONTINUE", prominent: true, action: commit)
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.35)
                .animation(MMotion.micro, value: canContinue)
                .accessibilityIdentifier("cta-continue")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func commit() {
        guard canContinue else { return }
        let config = MinusContainer.userConfig(in: deps.context)
        config.intentionText = trimmed
        advance()
    }
}
