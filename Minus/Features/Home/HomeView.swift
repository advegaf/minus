import SwiftData
import SwiftUI

/// The monument. Everything the user sees fifty times a day, composed top→down
/// on the obsidian void and locked to a single 20pt leading margin: the stacked
/// clock, their intention, the essentials launcher, then — pinned low — the
/// focus state and the ghost nav row.
struct HomeView: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(AppRouter.self) private var router
    @Query private var configs: [UserConfig]

    private var intention: String {
        guard let config = configs.first(where: { $0.id == UserConfig.wellKnownID }),
              config.showsIntention else { return "" }
        return config.intentionText
    }

    var body: some View {
        ZStack {
            MN.obsidian.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Fixed top block: the monument's origin is identical in every
                // state — the status slot below absorbs all variance (HO-9).
                Color.clear.frame(height: MN.Space.l)

                ClockDisplay()

                if !intention.isEmpty {
                    // Tapping the goal edits the goal (v1.8 friction pass).
                    // No minHit frame here: the monument's spacing must stay
                    // byte-identical, so the text's own bounds are the target.
                    Button {
                        router.push(.settingsIntention)
                    } label: {
                        Text(intention)
                            .mnType(.body)
                            .foregroundStyle(MN.boneWhite)
                            .frame(maxWidth: 300, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.mnPress)
                    .padding(.top, MN.Space.m)
                    .accessibilityIdentifier("intention-line")
                }

                EssentialAppList()
                    .padding(.top, MN.Space.xl)

                Spacer(minLength: MN.Space.xs)

                FocusStateLine()

                NavTextRow(items: [
                    ("Focus", { router.push(.focus) }),
                    ("Awareness", { router.push(.awareness) }),
                    ("Settings", { router.push(.settings) }),
                ])
                .padding(.top, MN.Space.s)
                .padding(.bottom, MN.Space.m)
            }
            .padding(.horizontal, MN.Space.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

}
