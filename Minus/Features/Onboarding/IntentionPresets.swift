import SwiftUI

/// Predefined goals (G1): four intentions in the app voice, tappable wherever
/// the intention is written (onboarding + Settings). A tap fills the field —
/// the text stays editable, and editing away from a preset simply deselects it.
/// Slugs are stable identifiers (F-A): reordering or rewording a preset never
/// silently re-points automation at different copy.
enum IntentionPresets {
    struct Preset: Identifiable {
        var slug: String
        var text: String
        var id: String { slug }
    }

    static let all: [Preset] = [
        Preset(slug: "less-scrolling", text: "less scrolling. more reading."),
        Preset(slug: "present", text: "present with my people."),
        Preset(slug: "one-thing", text: "one thing at a time."),
        Preset(slug: "mornings", text: "mornings without the feed."),
    ]
}

struct IntentionPresetRows: View {
    @Binding var text: String

    var body: some View {
        VStack(spacing: 0) {
            ForEach(IntentionPresets.all) { preset in
                OnboardingSelectRow(
                    title: preset.text,
                    isSelected: text == preset.text,
                    accessibilityID: "preset-\(preset.slug)"
                ) {
                    text = preset.text
                }
            }
        }
    }
}
