import SwiftData
import SwiftUI

/// The typeface picker. minus is one typeface at a time, but which one is the
/// user's call, so this screen is mostly specimen: the clock's own numerals
/// at the top, and five rows each set in the face they name.
struct TypefaceView: View {
    @Environment(AppDependencies.self) private var deps
    @Query private var configs: [UserConfig]

    private var current: MTypeface {
        MTypeface.resolve(configs.first { $0.id == UserConfig.wellKnownID }?.typefaceRaw)
    }

    var body: some View {
        SettingsShell(eyebrow: "TYPEFACE", id: "settings-typeface", scrolls: true) {
            Text("What should minus read like?")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)

            specimen
                .padding(.top, MN.Space.l)

            VStack(spacing: 0) {
                // Only faces that actually resolved. A missing .otf shrinks
                // the list rather than offering a pick that would silently
                // fall back to the system font.
                ForEach(MTypeface.registered, id: \.self) { face in
                    row(face)
                }
            }
            .padding(.top, MN.Space.m)

            Text("every screen, your widgets, and the report change together.")
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)
                .padding(.top, MN.Space.m)

            Spacer()
        }
    }

    /// The app's own numerals, because the home screen is a 96pt clock and a
    /// face that cannot carry big figures cannot carry minus. Fixed height so
    /// the list never jumps as faces swap.
    private var specimen: some View {
        FixedDigits(text: "09:41", token: .displaySm)
            .environment(\.mnTypeface, current)
            .frame(height: MNType.displaySm.size * 1.1, alignment: .leading)
            .animation(MMotion.micro, value: current)
            .accessibilityIdentifier("typeface-specimen")
    }

    private func row(_ face: MTypeface) -> some View {
        VStack(alignment: .leading, spacing: MN.Space.xxs) {
            OnboardingSelectRow(
                title: face.displayName,
                isSelected: face == current,
                accessibilityID: "typeface-\(face.rawValue)"
            ) {
                pick(face)
            }
            Text(face.note)
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
                .padding(.bottom, MN.Space.s)
        }
        // The row names a face and is set in it, so choosing is reading.
        .environment(\.mnTypeface, face)
    }

    private func pick(_ face: MTypeface) {
        let config = MinusContainer.userConfig(in: deps.context)
        config.typeface = face
        try? deps.context.save()
        // Republish now rather than waiting for the next scene change, so the
        // widgets are already in the new face when the user gets home.
        deps.publishLauncher()
    }
}
