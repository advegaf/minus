import SwiftUI

/// The manual: how to finish turning the phone into a dumb phone. Static,
/// honest, ten minutes by hand — Apple doesn't let apps rearrange the home
/// screen, and the copy says so instead of pretending.
struct DumbPhoneGuideView: View {
    private static let steps: [(title: String, body: String)] = [
        ("the widget is the phone",
         "long-press your home screen, tap +, search minus, add the large launcher. your essentials, one tap each."),
        ("one page",
         "in jiggle mode, tap the page dots and uncheck every page except the widget's. one page is enough."),
        ("the app library is enough",
         "everything else lives one swipe right. in settings → home screen & app library, turn off notification badges in the library."),
        ("only humans ring",
         "allow notifications for phone, messages, and facetime. silence the rest — apps don't get to interrupt you."),
        ("the small widget",
         "add the focus widget too, so a running session is visible from the home screen."),
        ("let it disappear",
         "long-press the home screen → edit → customize → set the widget style to clear. on a dark wallpaper the launcher becomes floating words — no widget, just glass."),
        ("the four that ring",
         "in shortcuts, make four one-action shortcuts — open app → phone, named minus-phone. repeat for messages, facetime, mail. apple only lets shortcuts open these to their real screens; minus routes their taps through yours."),
        ("any app at all",
         "added a custom app to a card? make one more shortcut the same way — open app → the app, named exactly what minus showed you (minus-yourapp). one shortcut per custom app, once."),
    ]

    var body: some View {
        SettingsShell(eyebrow: "DUMB PHONE", id: "settings-guide", scrolls: true) {
            Text("Ten minutes, once.")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)

            VStack(alignment: .leading, spacing: MN.Space.l) {
                ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, step in
                    VStack(alignment: .leading, spacing: MN.Space.xs) {
                        Text(String(format: "%02d \u{00B7} %@", index + 1, step.title))
                            .mnType(.caption)
                            .textCase(.uppercase)
                            .foregroundStyle(MN.fogBlue)
                        Text(step.body)
                            .mnType(.body)
                            .foregroundStyle(MN.boneWhite)
                            .frame(maxWidth: 340, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("guide-step-\(index + 1)")
                }
            }
            .padding(.top, MN.Space.l)

            Text("minus can't rearrange your home screen for you — apple doesn't allow it. ten minutes by hand, once.")
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 340, alignment: .leading)
                .padding(.top, MN.Space.section)
                .padding(.bottom, MN.Space.l)
                .accessibilityIdentifier("guide-honesty")
        }
    }
}
