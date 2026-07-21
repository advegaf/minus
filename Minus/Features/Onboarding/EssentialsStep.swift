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

            Text("the few apps that earn a place — up to \(cap).")
                .mnType(.body)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(EssentialAppCatalog.all.enumerated()), id: \.element.id) { index, app in
                        let isSelected = selected.contains(app.slug)
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
                            MMotion.micro.delay(Double(index) * MMotion.staggerStep),
                            value: appeared
                        )
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

    private func commit() {
        guard !selected.isEmpty else { return }
        let context = deps.context

        // Idempotent: clear any prior picks so a re-run never duplicates rows.
        if let existing = try? context.fetch(FetchDescriptor<EssentialApp>()) {
            for row in existing { context.delete(row) }
        }
        for (order, slug) in selected.enumerated() {
            guard let app = EssentialAppCatalog.app(slug: slug) else { continue }
            context.insert(
                EssentialApp(
                    slug: app.slug,
                    displayName: app.displayName,
                    urlScheme: app.urlString,
                    sortOrder: order
                )
            )
        }
        advance()
    }
}
