import SwiftData
import XCTest
@testable import Minus

/// v1.6 cards data layer: the fold, the snapshot v2 fallback chain, the pure
/// bridge assembly, and custom-slug generation.
@MainActor
final class LauncherCardTests: XCTestCase {
    /// Containers must outlive their contexts: on the iOS 27 SwiftData the
    /// mainContext no longer retains its container, and an unretained one
    /// deallocates mid-test (SIGTRAP inside SwiftData — found in Phase 0).
    private var containers: [ModelContainer] = []

    override func tearDown() {
        containers.removeAll()
        super.tearDown()
    }

    private func freshContext() -> ModelContext {
        let container = MinusContainer.make(inMemory: true)
        containers.append(container)
        return container.mainContext
    }

    // MARK: migrateToCards fold

    func testFoldTurnsCatalogRowsIntoCardOne() throws {
        let context = freshContext()
        for (index, slug) in ["phone", "maps", "music"].enumerated() {
            context.insert(EssentialApp(slug: slug, displayName: slug, urlScheme: "x:", sortOrder: index))
        }
        AppDependencies.migrateToCards(context: context)

        let cards = MinusContainer.cards(in: context)
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.first?.name, "one")
        XCTAssertEqual(cards.first?.orderedSlugs, ["phone", "maps", "music"])
        // Catalog rows are consumed; the registry is customs-only now.
        let remaining = (try context.fetch(FetchDescriptor<EssentialApp>()))
        XCTAssertTrue(remaining.isEmpty)
    }

    func testFoldIsIdempotent() {
        let context = freshContext()
        context.insert(EssentialApp(slug: "phone", displayName: "Phone", urlScheme: "tel:", sortOrder: 0))
        AppDependencies.migrateToCards(context: context)
        AppDependencies.migrateToCards(context: context)
        XCTAssertEqual(MinusContainer.cards(in: context).count, 1)
    }

    func testFoldLeavesCustomRowsAlone() throws {
        let context = freshContext()
        context.insert(EssentialApp(slug: "phone", displayName: "Phone", urlScheme: "tel:", sortOrder: 0))
        context.insert(EssentialApp(slug: "custom-yoga", displayName: "Yoga", urlScheme: "", sortOrder: 1))
        AppDependencies.migrateToCards(context: context)

        let remaining = try context.fetch(FetchDescriptor<EssentialApp>())
        XCTAssertEqual(remaining.map(\.slug), ["custom-yoga"])
        XCTAssertEqual(MinusContainer.cards(in: context).first?.orderedSlugs, ["phone"])
    }

    func testFoldNoOpsWhenCardsExist() {
        let context = freshContext()
        context.insert(LauncherCard(name: "one", orderedSlugs: ["maps"], sortOrder: 0))
        context.insert(EssentialApp(slug: "phone", displayName: "Phone", urlScheme: "tel:", sortOrder: 0))
        AppDependencies.migrateToCards(context: context)

        let cards = MinusContainer.cards(in: context)
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.first?.orderedSlugs, ["maps"])
    }

    func testFoldCapsAtHomeCap() {
        let context = freshContext()
        let slugs = ["phone", "messages", "facetime", "mail", "maps", "music", "photos", "calendar", "notes"]
        for (index, slug) in slugs.enumerated() {
            context.insert(EssentialApp(slug: slug, displayName: slug, urlScheme: "x:", sortOrder: index))
        }
        AppDependencies.migrateToCards(context: context)
        XCTAssertEqual(MinusContainer.cards(in: context).first?.orderedSlugs.count, EssentialAppCatalog.homeCap)
    }

    // MARK: snapshot v2 fallback chain

    func testV1FileDecodesAndResolvesImplicitCard() throws {
        // A v1.5 snapshot JSON has no "cards" key at all.
        let v1JSON = """
        {"essentials":[{"slug":"phone","name":"phone","url":"tel:","installed":true}],
         "intention":"less.","focus":{},"generatedAt":"2026-01-01T00:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(LauncherSnapshot.self, from: Data(v1JSON.utf8))

        XCTAssertNil(snapshot.cards)
        let resolved = snapshot.resolvedCards
        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved.first?.id, LauncherSnapshot.implicitCardID)
        XCTAssertEqual(resolved.first?.essentials.map(\.slug), ["phone"])
    }

    func testCardLookupFallsBackToFirst() {
        let snapshot = LauncherSnapshot.fixture
        XCTAssertEqual(snapshot.card(id: nil)?.id, LauncherSnapshot.implicitCardID)
        // A deleted card's id resolves to card 1 rather than nothing.
        XCTAssertEqual(snapshot.card(id: UUID())?.id, LauncherSnapshot.implicitCardID)
    }

    // MARK: bridge assembly

    func testBridgeResolvesCatalogAndCustomSlugs() {
        let cardID = UUID()
        let snapshot = LauncherBridge.snapshot(
            cards: [
                LauncherBridge.CardInput(id: cardID, name: "one", orderedSlugs: ["phone", "custom-yoga", "ghost-slug"])
            ],
            customEntries: ["custom-yoga": "Yoga"],
            intention: "less.",
            activeSnapshot: nil,
            schedules: [],
            now: Date(timeIntervalSince1970: 1_000)
        )

        let card = snapshot.resolvedCards[0]
        XCTAssertEqual(card.id, cardID)
        // ghost-slug resolves nowhere and drops out silently.
        XCTAssertEqual(card.essentials.map(\.slug), ["phone", "custom-yoga"])
        XCTAssertNil(card.essentials[0].installed, "v1.8 never probes")
        XCTAssertNil(card.essentials[1].installed, "v1.8 never probes")
        // Top-level essentials mirrors card 1 for stale-reader compat.
        XCTAssertEqual(snapshot.essentials.map(\.slug), card.essentials.map(\.slug))
    }



    // MARK: v1.7 — goal visibility + per-card row resolution

    func testIntentionIsShownByDefault() {
        let context = freshContext()
        XCTAssertTrue(
            MinusContainer.userConfig(in: context).showsIntention,
            "a fresh (or migrated) config must default to showing the goal"
        )
    }

    func testRowsResolvePerCard() {
        let card = LauncherCard(
            name: "work",
            orderedSlugs: ["slack", "custom-pilates", "ghost-slug"],
            sortOrder: 1
        )
        let rows = EssentialAppList.rows(for: card, customs: ["custom-pilates": "Pilates"])
        XCTAssertEqual(rows.map(\.slug), ["slack", "custom-pilates"], "unknown slugs drop out")
        XCTAssertEqual(rows[0].name, "Slack")
        XCTAssertEqual(rows[1].name, "Pilates")
    }

    // MARK: v1.9 launch plans

    func testLaunchPlanTriesSchemeThenLinkThenShortcut() {
        let plan = EssentialLaunchURL.launchPlan(
            slug: "spotify", urlString: "spotify:", universalLink: "https://open.spotify.com"
        ).map(\.absoluteString)
        XCTAssertEqual(plan, [
            "spotify:",
            "https://open.spotify.com",
            "shortcuts://run-shortcut?name=minus-spotify",
        ])
    }

    func testLaunchPlanWithoutUniversalLinkStartsAtTheScheme() {
        let plan = EssentialLaunchURL.launchPlan(
            slug: "notes", urlString: "mobilenotes:", universalLink: nil
        ).map(\.absoluteString)
        XCTAssertEqual(plan, ["mobilenotes:", "shortcuts://run-shortcut?name=minus-notes"])
    }

    func testCommAndCustomSlugsOnlyEverUseTheShortcut() {
        for slug in ["phone", "messages", "facetime", "mail"] {
            XCTAssertEqual(
                EssentialLaunchURL.launchPlan(slug: slug, urlString: "tel:", universalLink: "https://x.com")
                    .map(\.absoluteString),
                ["shortcuts://run-shortcut?name=minus-\(slug)"],
                slug
            )
        }
        XCTAssertEqual(
            EssentialLaunchURL.launchPlan(slug: "custom-pilates", urlString: "", universalLink: nil)
                .map(\.absoluteString),
            ["shortcuts://run-shortcut?name=minus-pilates"]
        )
    }

    /// Apple's own apps carry no link, so they always bounce through minus.
    func testAppleAppsBounce() {
        XCTAssertEqual(
            EssentialLaunchURL.widgetTarget(
                slug: "notes", urlString: "mobilenotes:", universalLink: nil, linkVerified: false
            )?.absoluteString,
            "minus://open/notes"
        )
    }


    // MARK: custom slugs

    func testCustomSlugGeneration() {
        XCTAssertEqual(CustomSlug.make(name: "Pilates Studio", existing: []), "custom-pilates-studio")
        // alphanumerics keeps accented letters — the preview shows the exact
        // shortcut name to create, so "café" stays "café".
        XCTAssertEqual(CustomSlug.make(name: "  Café +1  ", existing: []), "custom-café-1")
        XCTAssertEqual(CustomSlug.make(name: "!!!", existing: []), "custom-app")
        XCTAssertEqual(
            CustomSlug.make(name: "Yoga", existing: ["custom-yoga"]),
            "custom-yoga-2"
        )
        XCTAssertEqual(
            CustomSlug.make(name: "Yoga", existing: ["custom-yoga", "custom-yoga-2"]),
            "custom-yoga-3"
        )
    }

    func testCustomSlugRoundTripsThroughResolver() {
        let slug = CustomSlug.make(name: "Pilates", existing: [])
        XCTAssertTrue(CustomSlug.isCustom(slug))
        XCTAssertEqual(CustomSlug.bare(slug), "pilates")
        XCTAssertEqual(
            EssentialLaunchURL.resolve(slug: slug, urlString: "")?.absoluteString,
            "shortcuts://run-shortcut?name=minus-pilates"
        )
    }

    /// CustomSlug (app target) and EssentialLaunchURL (shared into the widget,
    /// so it can't import the data layer) each carry the prefix — lockstep.
    func testCustomPrefixesAgree() {
        XCTAssertEqual(CustomSlug.prefix, EssentialLaunchURL.customPrefix)
    }
}
