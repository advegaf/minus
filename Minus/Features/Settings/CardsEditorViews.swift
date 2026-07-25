import SwiftData
import SwiftUI

// v1.6: the essentials editor grew into cards, named launcher pages. Card 1
// is Home and the default widget; every placed widget can pick its own card
// in Edit Widget. Three screens: list, detail, custom entry.

// MARK: - Cards list

struct CardsListView: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(AppRouter.self) private var router
    @Query(sort: \LauncherCard.sortOrder) private var cards: [LauncherCard]

    var body: some View {
        SettingsShell(eyebrow: "CARDS", id: "settings-cards", scrolls: true) {
            Text("Your cards.")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)
            Text("each card is one launcher page. the first is home; any widget can show any card.")
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)
                .padding(.top, MN.Space.xs)

            VStack(spacing: 0) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    Button {
                        router.push(.settingsCard(id: card.id))
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: MN.Space.xs) {
                            Text(card.name.isEmpty ? "untitled" : card.name.lowercased())
                                .mnType(.bodyLg)
                                .foregroundStyle(MN.boneWhite)
                            Text(appsLine(card))
                                .mnType(.caption)
                                .foregroundStyle(MN.fogBlue)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: MN.minHit, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.mnPress)
                    .accessibilityIdentifier("card-row-\(index)")
                    .overlay(alignment: .bottom) {
                        if index < cards.count - 1 {
                            Rectangle().fill(MN.ashBorder).frame(height: MN.hairline)
                        }
                    }
                }
            }
            .padding(.top, MN.Space.m)

            if cards.count < MinusContainer.cardCap {
                OutlinedCTA(title: "NEW CARD", action: addCard)
                    .padding(.top, MN.Space.l)
                    .accessibilityIdentifier("cta-new-card")
            }
        }
    }

    private func appsLine(_ card: LauncherCard) -> String {
        let count = card.orderedSlugs.count
        return count == 1 ? "1 app" : "\(count) apps"
    }

    private func addCard() {
        guard let card = MinusContainer.addCard(in: deps.context) else { return }
        deps.publishLauncher()
        router.push(.settingsCard(id: card.id))
    }
}

// MARK: - Card detail

struct CardDetailView: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(AppRouter.self) private var router
    @Query(sort: \LauncherCard.sortOrder) private var cards: [LauncherCard]
    @Query(sort: \EssentialApp.sortOrder) private var registry: [EssentialApp]

    /// nil = the first card (deep-jump tours have no id at parse time).
    let cardID: UUID?

    @State private var name = ""
    @State private var loaded = false
    @State private var confirmingDelete = false

    private var card: LauncherCard? {
        cardID.flatMap { id in cards.first { $0.id == id } } ?? (cardID == nil ? cards.first : nil)
    }
    private var customs: [EssentialApp] { registry.filter { CustomSlug.isCustom($0.slug) } }
    private var atCap: Bool { (card?.orderedSlugs.count ?? 0) >= EssentialAppCatalog.homeCap }

    var body: some View {
        SettingsShell(eyebrow: "CARD", id: "settings-card-detail", scrolls: true) {
            FieldShell(placeholder: "card name", text: $name, accessibilityID: "field-card-name")
                .onChange(of: name) { _, newValue in
                    guard loaded, let card, card.name != newValue else { return }
                    card.name = newValue
                    try? deps.context.save()
                }

            Text("up to \(EssentialAppCatalog.homeCap). order follows when you added them.")
                .mnType(.caption)
                .foregroundStyle(MN.fogBlue)
                .padding(.top, MN.Space.xs)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(CatalogCategory.allCases, id: \.rawValue) { category in
                    Text(category.rawValue)
                        .mnType(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(MN.fogBlue)
                        .padding(.top, MN.Space.m)
                        .padding(.bottom, MN.Space.xxs)
                    ForEach(EssentialAppCatalog.apps(in: category)) { app in
                        let isChosen = card?.orderedSlugs.contains(app.slug) ?? false
                        OnboardingSelectRow(
                            title: app.displayName.lowercased(),
                            isSelected: isChosen,
                            isDimmed: !isChosen && atCap,
                            accessibilityID: "edit-row-\(app.slug)"
                        ) {
                            toggle(app.slug, isChosen: isChosen)
                        }
                    }
                }

                Text("yours")
                    .mnType(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(MN.fogBlue)
                    .padding(.top, MN.Space.m)
                    .padding(.bottom, MN.Space.xxs)
                ForEach(customs, id: \.slug) { entry in
                    let isChosen = card?.orderedSlugs.contains(entry.slug) ?? false
                    OnboardingSelectRow(
                        title: entry.displayName.lowercased(),
                        isSelected: isChosen,
                        isDimmed: !isChosen && atCap,
                        accessibilityID: "edit-row-\(entry.slug)"
                    ) {
                        toggle(entry.slug, isChosen: isChosen)
                    }
                }
                Button {
                    router.push(.settingsCustom(cardID: cardID))
                } label: {
                    Text("+ an app we don't list")
                        .mnType(.body)
                        .foregroundStyle(MN.boneWhite)
                        .frame(maxWidth: .infinity, minHeight: MN.minHit, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.mnPress)
                .accessibilityIdentifier("cta-add-custom")
            }
            .padding(.top, MN.Space.m)

            Button {
                confirmingDelete = true
            } label: {
                Text("delete this card")
                    .mnType(.body)
                    .foregroundStyle(MN.fogBlue)
                    .frame(maxWidth: .infinity, minHeight: MN.minHit, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.mnPress)
            .padding(.top, MN.Space.section)
            .padding(.bottom, MN.Space.l)
            .accessibilityIdentifier("cta-delete-card")
        }
        .confirmationDialog(
            "Delete this card?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteCard() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("widgets showing it fall back to your first card.")
        }
        .onAppear {
            guard !loaded else { return }
            name = card?.name ?? ""
            loaded = true
        }
    }

    private func toggle(_ slug: String, isChosen: Bool) {
        guard let card else { return }
        if isChosen {
            card.orderedSlugs.removeAll { $0 == slug }
        } else {
            guard !atCap else { return }
            card.orderedSlugs.append(slug)
        }
        try? deps.context.save()
        deps.publishLauncher()
    }

    private func deleteCard() {
        guard let card else { return }
        let dyingID = card.id
        deps.context.delete(card)
        // The launcher never goes cardless: an empty "one" takes its place
        // when the last card dies (Home + widgets keep a stable anchor).
        if cards.filter({ $0.id != dyingID }).isEmpty {
            deps.context.insert(LauncherCard(name: "one", orderedSlugs: [], sortOrder: 0))
        }
        try? deps.context.save()
        deps.publishLauncher()
        router.pop()
    }
}

// MARK: - Custom entry

struct CustomEntryView: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(AppRouter.self) private var router
    @Query(sort: \LauncherCard.sortOrder) private var cards: [LauncherCard]
    @Query(sort: \EssentialApp.sortOrder) private var registry: [EssentialApp]

    /// nil = the first card (deep-jump tours have no id at parse time).
    let cardID: UUID?

    @State private var name = ""
    @State private var matches: [AppSearch.Match] = []
    @State private var status: Status = .idle
    @State private var searchTask: Task<Void, Never>?

    private enum Status: Equatable { case idle, searching, empty, offline }

    var body: some View {
        SettingsShell(eyebrow: "ADD AN APP", id: "settings-custom", scrolls: true) {
            Text("Any app at all.")
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)

            Text("type its name. minus asks the app store for its identity once, then opens it directly from then on.")
                .mnType(.body)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)
                .padding(.top, MN.Space.s)

            FieldShell(placeholder: "app name", text: $name, accessibilityID: "field-custom-name", autofocus: true)
                .padding(.top, MN.Space.l)
                .onChange(of: name) { _, value in search(value) }

            statusLine.padding(.top, MN.Space.xs)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(matches) { match in
                    Button { add(match) } label: {
                        VStack(alignment: .leading, spacing: MN.Space.xxs) {
                            Text(match.name.lowercased())
                                .mnType(.bodyLg)
                                .foregroundStyle(MN.boneWhite)
                                .lineLimit(1)
                            Text(match.seller.lowercased())
                                .mnType(.caption)
                                .foregroundStyle(MN.fogBlue)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: MN.minHit, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.mnPress)
                    .padding(.vertical, MN.Space.xxs)
                    .accessibilityIdentifier("app-match-\(match.bundleID)")
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(MN.ashBorder).frame(height: MN.hairline)
                    }
                }
            }
            .padding(.top, MN.Space.m)
            .animation(MMotion.micro, value: matches)
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch status {
        case .idle:
            EmptyView()
        case .searching:
            caption("looking\u{2026}")
        case .empty:
            caption("nothing by that name. try the app's exact title.")
        case .offline:
            caption("no connection. adding an app needs one, once; opening never does.")
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .mnType(.caption)
            .foregroundStyle(MN.fogBlue)
            .frame(maxWidth: 320, alignment: .leading)
            .accessibilityIdentifier("search-status")
    }

    /// One query per typed word, not one per keystroke.
    private func search(_ term: String) {
        searchTask?.cancel()
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            matches = []
            status = .idle
            return
        }
        status = .searching
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            do {
                let found = try await AppSearch.matches(for: trimmed)
                guard !Task.isCancelled else { return }
                matches = found
                status = .idle
            } catch AppSearch.Failure.offline {
                guard !Task.isCancelled else { return }
                matches = []
                status = .offline
            } catch {
                guard !Task.isCancelled else { return }
                matches = []
                status = .empty
            }
        }
    }

    private func add(_ match: AppSearch.Match) {
        let slug = CustomSlug.make(name: match.name, existing: Set(registry.map(\.slug)))
        let nextOrder = (registry.map(\.sortOrder).max() ?? -1) + 1
        deps.context.insert(
            EssentialApp(
                slug: slug,
                displayName: match.name,
                urlScheme: "",
                sortOrder: nextOrder,
                bundleID: match.bundleID
            )
        )
        let target = cardID.flatMap { id in cards.first { $0.id == id } } ?? cards.first
        if let target, target.orderedSlugs.count < EssentialAppCatalog.homeCap {
            target.orderedSlugs.append(slug)
        }
        try? deps.context.save()
        deps.publishLauncher()
        router.pop()
    }
}
