import SwiftUI

/// Text input with no box — just a single bottom hairline that brightens from
/// ash to bone-white on focus, transitioning with the micro curve. Input is
/// body-17 bone-white; the placeholder is fog-blue metadata.
struct FieldShell: View {
    let placeholder: String
    @Binding var text: String
    /// Accessibility identifier applied to the underlying text field.
    var accessibilityID: String

    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .mnType(.body)
                    .foregroundStyle(MN.fogBlue)
                    .allowsHitTesting(false)
            }
            TextField("", text: $text)
                .mnType(.body)
                .foregroundStyle(MN.boneWhite)
                .tint(MN.boneWhite)
                .textInputAutocapitalization(.never)
                .focused($focused)
                .accessibilityIdentifier(accessibilityID)
        }
        .padding(.vertical, MN.Space.xs)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(focused ? MN.boneWhite : MN.ashBorder)
                .frame(height: MN.hairline)
                .animation(MMotion.micro, value: focused)
        }
    }
}

#if DEBUG
private struct FieldShellPreview: View {
    @State private var empty = ""
    @State private var filled = "Morning ritual"

    var body: some View {
        ZStack {
            MN.obsidian.ignoresSafeArea()
            VStack(spacing: MN.Space.l) {
                FieldShell(placeholder: "Ritual name", text: $empty, accessibilityID: "field-empty")
                FieldShell(placeholder: "Ritual name", text: $filled, accessibilityID: "field-filled")
            }
            .padding(MN.Space.m)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    FieldShellPreview()
}
#endif
