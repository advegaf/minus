import AppIntents
import Foundation

/// The Edit-Widget face of a LauncherCard. COMPILED INTO BOTH TARGETS and
/// resolved ONLY through LauncherSnapshot.read() — the Edit-Widget sheet runs
/// in an extension process where SwiftData is off-limits (jetsam ceiling), and
/// the snapshot is the one contract both sides already share. Before minus
/// ever publishes, the fixture's implicit card keeps the picker non-empty.
struct CardEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Card"
    static let defaultQuery = CardQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    init(card: LauncherSnapshot.Card) {
        self.init(id: card.id, name: card.name.isEmpty ? "untitled" : card.name)
    }
}

struct CardQuery: EntityQuery {
    private func allCards() -> [CardEntity] {
        (LauncherSnapshot.read() ?? .fixture).resolvedCards.map(CardEntity.init(card:))
    }

    func entities(for identifiers: [UUID]) async throws -> [CardEntity] {
        allCards().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CardEntity] {
        allCards()
    }

    /// A freshly placed widget shows card 1 without a trip to Edit Widget.
    func defaultResult() async -> CardEntity? {
        allCards().first
    }
}
