import SwiftData
import SwiftUI
import UIKit

/// The launcher. v1.7: one page per card, swiped horizontally — the cards a
/// user builds in Settings become the thing their thumb moves through. Left-
/// aligned bodyLg rows, hairline ash rules between them only. Dimming is
/// honest: only a declared scheme that canOpenURL rejects reads "not
/// installed" — undeclared and custom entries never dim (opening needs no
/// declaration; probing does).
struct EssentialAppList: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \LauncherCard.sortOrder, order: .forward)
    private var cards: [LauncherCard]
    @Query(filter: #Predicate<EssentialApp> { $0.isEnabled },
           sort: \EssentialApp.sortOrder, order: .forward)
    private var registry: [EssentialApp]

    /// Flips exactly once, on first appearance, to drive the staggered reveal.
    /// It never resets, so data-driven re-renders don't re-stagger — and a
    /// swipe never re-runs the entrance.
    @State private var appeared = false
    /// Session-scoped: a cold launch always rests on card one, matching what
    /// the widgets publish.
    @State private var activeCardID: UUID?

    struct Row: Identifiable {
        var slug: String
        var name: String
        var url: URL?
        var installed: Bool

        var id: String { slug }
    }

    /// Pure resolution for one card — catalog rows carry their compiled-in
    /// name/scheme (probed only when declared), "custom-" slugs resolve from
    /// the registry, unknown slugs drop out silently.
    static func rows(
        for card: LauncherCard,
        customs: [String: String],
        installedCheck: (URL) -> Bool
    ) -> [Row] {
        card.orderedSlugs.compactMap { slug in
            if let app = EssentialAppCatalog.app(slug: slug) {
                let installed = !app.declared || (app.url.map(installedCheck) ?? false)
                return Row(
                    slug: slug,
                    name: app.displayName,
                    url: EssentialLaunchURL.resolve(slug: slug, urlString: app.urlString),
                    installed: installed
                )
            }
            if let name = customs[slug] {
                return Row(
                    slug: slug,
                    name: name,
                    url: EssentialLaunchURL.resolve(slug: slug, urlString: ""),
                    installed: true
                )
            }
            return nil
        }
    }

    private var customs: [String: String] {
        Dictionary(
            registry.filter { CustomSlug.isCustom($0.slug) }.map { ($0.slug, $0.displayName) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private var activeCard: LauncherCard? {
        cards.first { $0.id == activeCardID } ?? cards.first
    }

    var body: some View {
        Group {
            if cards.isEmpty {
                emptyState
            } else if cards.count == 1 {
                page(for: cards[0])
            } else {
                pager
            }
        }
        .onAppear {
            appeared = true
            if activeCardID == nil { activeCardID = cards.first?.id }
        }
        .onChange(of: cards) { _, updated in
            // A deleted card must not strand the pager on nothing.
            if !updated.contains(where: { $0.id == activeCardID }) {
                activeCardID = updated.first?.id
            }
        }
    }

    // MARK: Pager

    private var pager: some View {
        VStack(alignment: .leading, spacing: MN.Space.xs) {
            cardTabs

            ScrollView(.horizontal) {
                // Plain HStack, not lazy: ≤7 text rows per card, and the
                // stack sizes to the tallest page ONCE — so the monument
                // never jumps vertically mid-swipe.
                HStack(alignment: .top, spacing: 0) {
                    ForEach(cards) { card in
                        page(for: card)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $activeCardID)
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("card-pager")
        }
    }

    /// The only chrome the pager gets: card names as caption text — bone for
    /// where you are, fog for where you could go. Same vocabulary as the ghost
    /// nav row, so it reads as part of the app rather than as widget dots.
    /// Tappable too — swipe is the gesture, tap is the shortcut.
    private var cardTabs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: MN.Space.s) {
                ForEach(cards) { card in
                    let isActive = card.id == activeCard?.id
                    Button {
                        withAnimation(MMotion.signature) { activeCardID = card.id }
                    } label: {
                        Text(card.name.isEmpty ? "untitled" : card.name.lowercased())
                            .mnType(.caption)
                            .foregroundStyle(isActive ? MN.boneWhite : MN.fogBlue)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.mnPress)
                    .accessibilityIdentifier("card-tab-\(card.name.lowercased())")
                }
            }
        }
        .scrollIndicators(.hidden)
        .animation(MMotion.micro, value: activeCardID)
        .accessibilityIdentifier("card-tabs")
    }

    // MARK: One card

    @ViewBuilder
    private func page(for card: LauncherCard) -> some View {
        let resolved = Self.rows(
            for: card,
            customs: customs,
            installedCheck: { UIApplication.shared.canOpenURL($0) }
        )
        if resolved.isEmpty {
            emptyState
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(resolved.enumerated()), id: \.element.slug) { index, row in
                    if index > 0 {
                        Rectangle()
                            .fill(MN.ashBorder)
                            .frame(height: MN.hairline)
                    }
                    AppRow(row: row, openURL: openURL)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: (appeared || reduceMotion) ? 0 : 6)
                        .animation(rowAnimation(index: index), value: appeared)
                }
            }
        }
    }

    /// Staggered rise on first paint; reduce-motion degrades to a single
    /// no-offset crossfade with no per-item delay.
    private func rowAnimation(index: Int) -> Animation {
        if reduceMotion {
            return .easeInOut(duration: 0.2)
        }
        return MMotion.micro.delay(Double(index) * MMotion.staggerStep)
    }

    private var emptyState: some View {
        Button {
            router.push(.settings)
        } label: {
            Text("nothing here yet — choose essentials in settings")
                .mnType(.body)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 300, minHeight: MN.minHit, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.mnPress)
        .accessibilityIdentifier("essentials-empty")
    }

    /// One launcher row. Installed → a bone-white button that opens the app.
    /// Uninstalled → a disabled, fog-dimmed row with a "not installed" suffix.
    private struct AppRow: View {
        let row: Row
        let openURL: OpenURLAction

        var body: some View {
            Button {
                if let url = row.url { openURL(url) }
            } label: {
                HStack(spacing: MN.Space.xs) {
                    Text(row.name.lowercased())
                        .mnType(.bodyLg)
                        .foregroundStyle(row.installed ? MN.boneWhite : MN.fogBlue)
                    if !row.installed {
                        Text("not installed")
                            .mnType(.caption)
                            .foregroundStyle(MN.fogBlue)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: MN.minHit, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.mnPress)
            .disabled(!row.installed)
            .opacity(row.installed ? 1 : 0.4)
            .accessibilityIdentifier("row-app-\(row.slug)")
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        MN.obsidian.ignoresSafeArea()
        EssentialAppList()
            .padding(MN.Space.m)
    }
    .preferredColorScheme(.dark)
}
#endif
