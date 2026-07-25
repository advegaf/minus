import SwiftData
import SwiftUI

/// The launcher. One page per card, swiped horizontally: the cards a user
/// builds in Settings become the thing their thumb moves through. Left-aligned
/// bodyLg rows, hairline ash rules between them only.
///
/// v1.8: nothing stands between a tap and the app. minus no longer guesses
/// whether something is installed (that guess was wrong on iOS 27 and it
/// disabled the row), so every row always taps. When a launch finds nothing,
/// one quiet line names the shortcut that would fix it.
struct EssentialAppList: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(AppRouter.self) private var router
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
    /// The slug whose last tap opened nothing. Clears itself after a beat.
    @State private var failedSlug: String?

    struct Row: Identifiable {
        var slug: String
        var name: String

        var id: String { slug }
    }

    /// Pure resolution for one card: catalog rows carry their compiled-in
    /// name and scheme, "custom-" slugs resolve from the registry, unknown
    /// slugs drop out silently.
    static func rows(for card: LauncherCard, customs: [String: String]) -> [Row] {
        var seen = Set<String>()
        return card.orderedSlugs.compactMap { slug in
            // A pre-1.6 store could fold duplicate rows into one card, and a
            // duplicate id collapses the ForEach that renders them.
            guard seen.insert(slug).inserted else { return nil }
            if let app = EssentialAppCatalog.app(slug: slug) {
                return Row(slug: slug, name: app.displayName)
            }
            if let name = customs[slug] {
                return Row(slug: slug, name: name)
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
                emptyState(for: nil)
            } else {
                VStack(alignment: .leading, spacing: MN.Space.xs) {
                    // The strip is present at every card count, so the
                    // launcher's origin never shifts as cards are born.
                    cardTabs
                    pager
                }
            }
        }
        .onAppear {
            appeared = true
            if activeCardID == nil { activeCardID = cards.first?.id }
        }
        // Belt and braces: `appeared` gates row opacity, and onAppear is
        // attached to a Group whose branch can be swapped underneath it. A
        // task on the same view cannot be skipped, so rows can never be left
        // invisible with the hairlines still drawn.
        .task { appeared = true }
        .onChange(of: cards) { _, updated in
            // A deleted card must not strand the pager on nothing.
            if !updated.contains(where: { $0.id == activeCardID }) {
                activeCardID = updated.first?.id
            }
        }
    }

    // MARK: Pager

    /// v1.10: ONLY the active card is built. The previous ScrollView pager
    /// kept every page mounted and drove position through scrollPosition(id:),
    /// which could rest between pages and show a blank launcher even though
    /// the card had apps (seen on device). One page cannot be the wrong page.
    ///
    /// Height is reserved for the longest card so the monument never jumps as
    /// you move between a one-app card and a seven-app one. Computed from the
    /// row metrics, never measured, so it is stable before first layout.
    private var pager: some View {
        Group {
            if let card = activeCard {
                page(for: card)
                    .id(card.id)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: reservedHeight, alignment: .topLeading)
        .contentShape(Rectangle())
        // Simultaneous, not exclusive: an exclusive gesture on the container
        // takes ownership of the whole block and the row buttons disappear
        // from the accessibility tree (caught by HomeUITests).
        .simultaneousGesture(cardSwipe)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card-pager")
    }

    /// The tallest card decides the reserved height: rows at the minimum hit
    /// target plus the hairlines between them.
    private var reservedHeight: CGFloat {
        let longest = cards.map { Self.rows(for: $0, customs: customs).count }.max() ?? 0
        guard longest > 0 else { return MN.minHit }
        return CGFloat(longest) * MN.minHit + CGFloat(longest - 1) * MN.hairline
    }

    /// Horizontal drag moves one card, the way the tabs above imply. Vertical
    /// intent is ignored, so the gesture never fights the page it sits on.
    private var cardSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                step(by: value.translation.width < 0 ? 1 : -1)
            }
    }

    private func step(by delta: Int) {
        guard cards.count > 1,
              let current = cards.firstIndex(where: { $0.id == activeCard?.id }) else { return }
        let next = current + delta
        guard cards.indices.contains(next) else { return }
        withAnimation(MMotion.signature) { activeCardID = cards[next].id }
    }

    /// The only chrome the launcher gets: card names as caption text, bone for
    /// where you are, fog for where you could go. Same vocabulary as the ghost
    /// nav row, so it reads as part of the app rather than as widget dots.
    /// Swipe is the gesture; tapping another name is the shortcut; tapping the
    /// name you are already on opens that card's editor; "+" starts a new one.
    private var cardTabs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: MN.Space.s) {
                ForEach(cards) { card in
                    let isActive = card.id == activeCard?.id
                    Button {
                        if isActive {
                            router.push(.settingsCard(id: card.id))
                        } else {
                            withAnimation(MMotion.signature) { activeCardID = card.id }
                        }
                    } label: {
                        Text(card.name.isEmpty ? "untitled" : card.name.lowercased())
                            .mnType(.caption)
                            .foregroundStyle(isActive ? MN.boneWhite : MN.fogBlue)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.mnPress)
                    .accessibilityIdentifier("card-tab-\(card.name.lowercased())")
                }

                if cards.count < MinusContainer.cardCap {
                    Button(action: addCard) {
                        Text("+")
                            .mnType(.caption)
                            .foregroundStyle(MN.fogBlue)
                            .frame(minWidth: MN.minHit, minHeight: MN.minHit, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.mnPress)
                    .padding(.leading, MN.Space.xs)
                    .accessibilityIdentifier("card-tab-new")
                }
            }
        }
        .scrollIndicators(.hidden)
        .animation(MMotion.micro, value: activeCardID)
        .accessibilityIdentifier("card-tabs")
    }

    private func addCard() {
        guard let card = MinusContainer.addCard(in: deps.context) else { return }
        withAnimation(MMotion.micro) { activeCardID = card.id }
        router.push(.settingsCard(id: card.id))
    }

    // MARK: One card

    @ViewBuilder
    private func page(for card: LauncherCard) -> some View {
        let resolved = Self.rows(for: card, customs: customs)
        if resolved.isEmpty {
            emptyState(for: card)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(resolved.enumerated()), id: \.element.slug) { index, row in
                    if index > 0 {
                        Rectangle()
                            .fill(MN.ashBorder)
                            .frame(height: MN.hairline)
                    }
                    AppRow(row: row) { launch(row) }
                        .opacity((appeared || reduceMotion) ? 1 : 0)
                        .offset(y: (appeared || reduceMotion) ? 0 : 6)
                        .animation(rowAnimation(index: index), value: appeared)
                }

                // The honest replacement for greying rows out: say what would
                // fix it, at the bottom of the page so no row moves. Home's
                // Spacer absorbs the growth, so the monument holds still.
                if let failedSlug, resolved.contains(where: { $0.slug == failedSlug }) {
                    Text("nothing opened. make a shortcut named \(EssentialLaunchURL.shortcutName(for: failedSlug)).")
                        .mnType(.caption)
                        .foregroundStyle(MN.fogBlue)
                        .frame(maxWidth: 320, alignment: .leading)
                        .padding(.top, MN.Space.xs)
                        .transition(.opacity)
                        .accessibilityIdentifier("launch-failed-\(failedSlug)")
                }
            }
            .task(id: failedSlug) {
                guard failedSlug != nil else { return }
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                withAnimation(MMotion.exit) { failedSlug = nil }
            }
        }
    }

    private func launch(_ row: Row) {
        Task {
            let opened = await EssentialLauncher.open(slug: row.slug)
            withAnimation(MMotion.micro) { failedSlug = opened ? nil : row.slug }
        }
    }

    /// Staggered rise on first paint; reduce-motion degrades to a single
    /// no-offset crossfade with no per-item delay.
    private func rowAnimation(index: Int) -> Animation {
        MMotion.settle(
            MMotion.micro.delay(Double(index) * MMotion.staggerStep),
            reduceMotion: reduceMotion
        )
    }

    /// An empty card says what is missing and goes straight to fixing it:
    /// the tap lands in THAT card's editor, not the settings root.
    private func emptyState(for card: LauncherCard?) -> some View {
        Button {
            if let card {
                router.push(.settingsCard(id: card.id))
            } else {
                router.push(.settingsEssentials)
            }
        } label: {
            (
                Text("nothing here yet. choose ")
                    .foregroundColor(MN.fogBlue)
                + Text("essentials")
                    .foregroundColor(MN.boneWhite)
            )
            .font(MNType.body.font)
            .tracking(MNType.body.tracking)
            .frame(maxWidth: 300, minHeight: MN.minHit, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.mnPress)
        .accessibilityIdentifier(card == nil ? "essentials-empty" : "essentials-empty-card")
    }

    /// One launcher row: a bone-white name that opens its app. Always enabled,
    /// always tappable. Nothing here guesses at installation.
    private struct AppRow: View {
        let row: Row
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                HStack(spacing: MN.Space.xs) {
                    Text(row.name.lowercased())
                        .mnType(.bodyLg)
                        .foregroundStyle(MN.boneWhite)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: MN.minHit, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.mnPress)
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
