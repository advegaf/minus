import SwiftUI

/// Predefined goals (G1): four intentions in the app voice, tappable wherever
/// the intention is written (onboarding + Settings). A tap fills the field —
/// the text stays editable, and editing away from a preset simply deselects it.
enum IntentionPresets {
    static let all = [
        "less scrolling. more reading.",
        "present with my people.",
        "one thing at a time.",
        "mornings without the feed.",
    ]
}

struct IntentionPresetRows: View {
    @Binding var text: String

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(IntentionPresets.all.enumerated()), id: \.offset) { index, preset in
                OnboardingSelectRow(
                    title: preset,
                    isSelected: text == preset,
                    accessibilityID: "preset-\(index + 1)"
                ) {
                    text = preset
                }
            }
        }
    }
}
