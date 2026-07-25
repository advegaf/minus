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
    /// The catalog covers a whole phone now, so browsing alone is ten screens
    /// of scrolling. Empty query keeps the categorised list exactly as it was.
    @State private var query = ""
    /// The added app awaiting a removal confirmation. Removal deletes the
    /// registry row itself, so it needs the same gate the card does.
    @State private var pendingRemoval: EssentialApp?
    /// The added app whose name is being edited in place. One at a time.
    @State private var renaming: EssentialApp?
    @State private var renameText = ""

    private var card: LauncherCard? {
        cardID.flatMap { id in cards.first { $0.id == id } } ?? (cardID == nil ? cards.first : nil)
    }
    private var customs: [EssentialApp] { registry.filter { CustomSlug.isCustom($0.slug) } }
    private var atCap: Bool { (card?.orderedSlugs.count ?? 0) >= EssentialAppCatalog.homeCap }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    private var isSearching: Bool { !trimmedQuery.isEmpty }

    /// Catalog rows matching the query. Prefix matches lead, because typing
    /// "ma" should reach maps before macrofactor's neighbours.
    private var catalogResults: [CatalogApp] {
        let term = trimmedQuery
        return EssentialAppCatalog.all
            .filter { $0.displayName.lowercased().contains(term) }
            .sorted { first, second in
                let firstLeads = first.displayName.lowercased().hasPrefix(term)
                let secondLeads = second.displayName.lowercased().hasPrefix(term)
                if firstLeads != secondLeads { return firstLeads }
                return first.displayName.lowercased() < second.displayName.lowercased()
            }
    }

    private var customResults: [EssentialApp] {
        customs.filter { $0.displayName.lowercased().contains(trimmedQuery) }
    }

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

            FieldShell(placeholder: "search apps", text: $query, accessibilityID: "field-app-search")
                .padding(.top, MN.Space.m)

            VStack(alignment: .leading, spacing: 0) {
                if isSearching {
                    searchResults
                } else {
                    browse
                }
            }
            .padding(.top, MN.Space.m)
            .animation(MMotion.micro, value: isSearching)

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
        .confirmationDialog(
            "Remove \(pendingRemoval?.displayName.lowercased() ?? "this app")?",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { removeAddedApp() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("it leaves every card. you can add it again by name.")
        }
        .onAppear {
            guard !loaded else { return }
            name = card?.name ?? ""
            loaded = true
        }
    }

    /// Everything minus knows, by category. Unchanged from when this was the
    /// only way to fill a card, just longer.
    @ViewBuilder
    private var browse: some View {
        ForEach(CatalogCategory.allCases, id: \.rawValue) { category in
            Text(category.rawValue)
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.fogBlue)
                .padding(.top, MN.Space.m)
                .padding(.bottom, MN.Space.xxs)
            ForEach(EssentialAppCatalog.apps(in: category)) { app in
                catalogRow(app)
            }
        }

        Text("yours")
            .mnType(.caption)
            .textCase(.uppercase)
            .foregroundStyle(MN.fogBlue)
            .padding(.top, MN.Space.m)
            .padding(.bottom, MN.Space.xxs)
        ForEach(customs, id: \.slug) { entry in
            addedRow(entry)
        }
        addByNameLink(label: "+ an app we don't list", id: "cta-add-custom")
            .padding(.top, MN.Space.xs)
    }

    /// One flat list, no eyebrows: when you have typed a name you are looking
    /// for one app, not browsing a shelf.
    @ViewBuilder
    private var searchResults: some View {
        let hasResults = !(catalogResults.isEmpty && customResults.isEmpty)
        if hasResults {
            ForEach(customResults, id: \.slug) { addedRow($0) }
            ForEach(catalogResults) { catalogRow($0) }
        } else {
            Text("nothing here by that name.")
                .mnType(.body)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 320, alignment: .leading)
                .accessibilityIdentifier("search-empty")
        }
        // The store knows apps minus never will, so the way out is always
        // offered — but it only speaks up when the search came back empty.
        // Sitting bone-white under a row the user already wanted, it competed
        // with the answer.
        addByNameLink(
            label: hasResults
                ? "not it? add by name"
                : "add \u{201c}\(trimmedQuery)\u{201d} by name",
            id: "cta-search-add",
            quiet: hasResults
        )
        .padding(.top, hasResults ? MN.Space.l : MN.Space.m)
    }

    private func catalogRow(_ app: CatalogApp) -> some View {
        let isChosen = card?.orderedSlugs.contains(app.slug) ?? false
        return OnboardingSelectRow(
            title: app.displayName.lowercased(),
            isSelected: isChosen,
            isDimmed: !isChosen && atCap,
            accessibilityID: "edit-row-\(app.slug)"
        ) {
            toggle(app.slug, isChosen: isChosen)
        }
    }

    /// Catalog rows can only be toggled; an app YOU added can also be taken
    /// back out, because a typo would otherwise sit in this list until the app
    /// was reinstalled.
    private func addedRow(_ entry: EssentialApp) -> some View {
        let isChosen = card?.orderedSlugs.contains(entry.slug) ?? false
        return AddedAppRow(
            title: entry.displayName.lowercased(),
            isSelected: isChosen,
            isDimmed: !isChosen && atCap,
            slug: entry.slug,
            isRenaming: renaming?.slug == entry.slug,
            renameText: $renameText,
            toggle: { toggle(entry.slug, isChosen: isChosen) },
            beginRename: {
                renameText = entry.displayName
                renaming = entry
            },
            commitRename: { commitRename() },
            remove: { pendingRemoval = entry }
        )
    }

    /// The store's title is a guess at the icon's name; this is the user
    /// saying what it actually is. Marked custom so nothing automatic
    /// overwrites it on a later launch.
    private func commitRename() {
        defer { renaming = nil }
        guard let entry = renaming else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != entry.displayName else { return }
        entry.displayName = trimmed
        entry.nameIsCustom = true
        try? deps.context.save()
        deps.publishLauncher()
    }

    private func addByNameLink(label: String, id: String, quiet: Bool = false) -> some View {
        Button {
            router.push(.settingsCustom(cardID: cardID, term: trimmedQuery))
        } label: {
            Text(label)
                .mnType(quiet ? .caption : .body)
                .foregroundStyle(quiet ? MN.fogBlue : MN.boneWhite)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: MN.minHit, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.mnPress)
        .accessibilityIdentifier(id)
    }

    /// Deleting the registry row is not enough: the slug is copied into every
    /// card that carries it, and a card holding a slug nothing resolves would
    /// render a ghost row.
    private func removeAddedApp() {
        guard let entry = pendingRemoval else { return }
        let slug = entry.slug
        for card in cards {
            card.orderedSlugs.removeAll { $0 == slug }
        }
        deps.context.delete(entry)
        try? deps.context.save()
        deps.publishLauncher()
        pendingRemoval = nil
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

/// An added app's row: the selection vocabulary on the left, and a quiet fog
/// "remove" on the right. Two buttons rather than one, so the destructive half
/// can never be hit by aiming at the name.
private struct AddedAppRow: View {
    let title: String
    let isSelected: Bool
    let isDimmed: Bool
    let slug: String
    let isRenaming: Bool
    @Binding var renameText: String
    let toggle: () -> Void
    let beginRename: () -> Void
    let commitRename: () -> Void
    let remove: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: MN.Space.xs) {
            Text("\u{2212}")
                .mnType(.bodyLg)
                .foregroundStyle(MN.boneWhite)
                .opacity(isSelected ? 1 : 0)
                .frame(width: MN.Space.m, alignment: .leading)

            if isRenaming {
                // The store's title is a guess at what the icon says. This is
                // where the user corrects it, in place, without leaving the
                // list they are already looking at.
                TextField("", text: $renameText)
                    .mnType(.bodyLg)
                    .foregroundStyle(MN.boneWhite)
                    .tint(MN.boneWhite)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .focused($focused)
                    .onSubmit(commitRename)
                    .onChange(of: focused) { _, hasFocus in
                        // Committing on blur too: tapping away is a save, not
                        // a discard, which is what a list of names expects.
                        if !hasFocus { commitRename() }
                    }
                    .task { focused = true }
                    .frame(maxWidth: .infinity, minHeight: MN.minHit, alignment: .leading)
                    .accessibilityIdentifier("field-rename-\(slug)")
            } else {
                // The name toggles, as every other row in this list does.
                // v1.16 made the name open the editor instead, which fought
                // the thing the row is mostly for: the obvious tap on a name
                // is "put this on the card", and it did something else.
                Button(action: toggle) {
                    HStack(spacing: 0) {
                        Text(title)
                            .mnType(.bodyLg)
                            .foregroundStyle(isSelected ? MN.boneWhite : MN.fogBlue)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: MN.minHit, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.mnPress)
                .disabled(isDimmed)
                .accessibilityIdentifier("edit-row-\(slug)")
                .accessibilityLabel(title)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])

                // Renaming is its own word. A pencil would have been the first
                // icon in the app; "rename" says what it does and looks like
                // everything else here.
                Button(action: beginRename) {
                    Text("rename")
                        .mnType(.caption)
                        .foregroundStyle(MN.fogBlue)
                        .frame(minWidth: MN.minHit, minHeight: MN.minHit, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.mnPress)
                .accessibilityIdentifier("rename-row-\(slug)")
                .accessibilityLabel("rename \(title)")
            }

            Button(action: remove) {
                Text("remove")
                    .mnType(.caption)
                    .foregroundStyle(MN.fogBlue)
                    .frame(minWidth: MN.minHit, minHeight: MN.minHit, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.mnPress)
            .padding(.leading, MN.Space.xs)
            .accessibilityIdentifier("remove-row-\(slug)")
            .accessibilityLabel("remove \(title)")
        }
        .opacity(isDimmed && !isRenaming ? 0.35 : 1)
        .overlay(alignment: .bottom) {
            // Bone while editing, ash otherwise: the same signal every other
            // field in the app gives when it has focus (see FieldShell), so
            // an editable row reads as a field rather than as a row that
            // happens to have a cursor in it.
            Rectangle()
                .fill(isRenaming ? MN.boneWhite : MN.ashBorder)
                .frame(height: MN.hairline)
                .animation(MMotion.micro, value: isRenaming)
        }
        .animation(MMotion.micro, value: isSelected)
        .animation(MMotion.micro, value: isDimmed)
        .animation(MMotion.micro, value: isRenaming)
    }
}

struct CustomEntryView: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(AppRouter.self) private var router
    @Query(sort: \LauncherCard.sortOrder) private var cards: [LauncherCard]
    @Query(sort: \EssentialApp.sortOrder) private var registry: [EssentialApp]

    /// nil = the first card (deep-jump tours have no id at parse time).
    let cardID: UUID?
    /// What was typed into the card editor's search before falling through to
    /// here. Carried so the same word is never typed twice.
    var term: String = ""

    @State private var name = ""
    @State private var matches: [AppSearch.Match] = []
    @State private var status: Status = .idle
    @State private var searchTask: Task<Void, Never>?

    private enum Status: Equatable { case idle, searching, empty, offline }

    init(cardID: UUID?, term: String = "") {
        self.cardID = cardID
        self.term = term
        // Seeded at init rather than onAppear: the carried term has to be in
        // the field before first paint, and the status line it used to hang
        // off is an EmptyView while idle, so its onAppear never ran.
        _name = State(initialValue: term)
    }

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
                    Button { Task { await add(match) } } label: {
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
        .task {
            // onChange never fires for a value that arrived with the view.
            guard !name.isEmpty, matches.isEmpty else { return }
            search(name)
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

    private func add(_ match: AppSearch.Match) async {
        // The row list above shows the full store title, because that is what
        // tells two similarly-named apps apart at the moment of choosing. What
        // gets STORED is the name the home screen uses.
        //
        // The device knows that name exactly and the App Store does not, so it
        // is asked first: "MacroFactor Workouts - Tracker" is all the store
        // has for the app whose icon reads "Workouts". If the lookup is
        // refused or the app is not installed, the shortened store title is
        // the honest second best, and the row can be renamed by hand.
        let name = await PrivateAppName.displayName(bundleID: match.bundleID)
            ?? AppName.short(match.name)
        let slug = CustomSlug.make(name: name, existing: Set(registry.map(\.slug)))
        let nextOrder = (registry.map(\.sortOrder).max() ?? -1) + 1
        deps.context.insert(
            EssentialApp(
                slug: slug,
                displayName: name,
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
