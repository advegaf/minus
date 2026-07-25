import SwiftData
import SwiftUI

/// The few apps that earn a place on Home. Tap to keep — colour is the state,
/// no checkboxes. Order of selection becomes their order on Home. A hard cap of
/// seven keeps the list honest; past it the rest dim away.
struct EssentialsStep: View {
    @Environment(AppDependencies.self) private var deps
    let advance: () -> Void

    /// Ordered by tap, so `sortOrder` on Home mirrors the choosing.
    @State private var selected: [String] = []
    @State private var appeared = false

    private let cap = EssentialAppCatalog.homeCap

    private var atCap: Bool { selected.count >= cap }

    var body: some View {
        VStack(alignment: .leading, spacing: MN.Space.m) {
            Text("What stays?")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)

            Text("the few apps that earn a place. up to \(cap).")
                .mnType(.body)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // v1.6: sixty apps — category eyebrows keep the wall
                    // walkable. Stagger only the first screenful; rows below
                    // the fold appear settled.
                    ForEach(CatalogCategory.allCases, id: \.rawValue) { category in
                        Text(category.rawValue)
                            .mnType(.caption)
                            .textCase(.uppercase)
                            .foregroundStyle(MN.fogBlue)
                            .padding(.top, MN.Space.m)
                            .padding(.bottom, MN.Space.xxs)
                        ForEach(EssentialAppCatalog.apps(in: category)) { app in
                            let isSelected = selected.contains(app.slug)
                            let index = rowIndex(of: app.slug)
                            OnboardingSelectRow(
                                title: app.displayName.lowercased(),
                                isSelected: isSelected,
                                isDimmed: atCap && !isSelected,
                                accessibilityID: "row-\(app.slug)",
                                action: { toggle(app.slug) }
                            )
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 8)
                            .animation(
                                MMotion.micro.delay(min(Double(index), 12) * MMotion.staggerStep),
                                value: appeared
                            )
                        }
                    }
                }
            }

            HStack {
                if atCap {
                    Text("\(cap) of \(cap)")
                        .mnType(.caption)
                        .foregroundStyle(MN.fogBlue)
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
            }
            .animation(MMotion.micro, value: atCap)

            OutlinedCTA(title: "CONTINUE", prominent: true, action: commit)
                .disabled(selected.isEmpty)
                .opacity(selected.isEmpty ? 0.35 : 1)
                .animation(MMotion.micro, value: selected.isEmpty)
                .accessibilityIdentifier("cta-continue")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { appeared = true }
    }

    private func toggle(_ slug: String) {
        if let idx = selected.firstIndex(of: slug) {
            selected.remove(at: idx)
        } else if !atCap {
            selected.append(slug)
        }
    }

    /// Flat position across the categorized list, for the entrance stagger.
    private func rowIndex(of slug: String) -> Int {
        EssentialAppCatalog.all.firstIndex { $0.slug == slug } ?? 0
    }

    private func commit() {
        guard !selected.isEmpty else { return }
        let context = deps.context

        // v1.6: the pick becomes card "one". Idempotent: clear any prior
        // cards so a re-run never duplicates.
        if let existing = try? context.fetch(FetchDescriptor<LauncherCard>()) {
            for card in existing { context.delete(card) }
        }
        context.insert(LauncherCard(name: "one", orderedSlugs: selected, sortOrder: 0))
        advance()
    }
}
