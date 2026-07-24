import Foundation
import SwiftData

enum MinusSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [UserConfig.self, EssentialApp.self, BlockList.self, FocusSession.self, FocusSchedule.self]
    }
}

/// v1.6: adds LauncherCard. Purely additive → lightweight stage.
enum MinusSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [UserConfig.self, EssentialApp.self, BlockList.self, FocusSession.self, FocusSchedule.self, LauncherCard.self]
    }
}

/// v1.7: UserConfig gains defaulted `showsIntention`.
///
/// NOTE — why there is no V3 stage: these VersionedSchemas share the LIVE
/// model classes, so every version describes whatever shape the classes have
/// today. A V2→V3 stage would therefore declare two identical shapes, and
/// SwiftData cannot map an on-disk store onto an ambiguous stage — it aborts
/// inside addPersistentStore (verified: signal abrt on launch against a v1.6
/// store). Additive, defaulted, CloudKit-legal properties don't need a stage:
/// the implicit lightweight migration below infers them. A stage only becomes
/// necessary for a genuinely destructive change (rename/retype/delete), and
/// that stage must snapshot the OLD shape in its own model types.

@MainActor
enum MinusContainer {
    static func make(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(versionedSchema: MinusSchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("minus: failed to create ModelContainer: \(error)")
        }
    }

    /// Fetch-or-create the UserConfig singleton (no #Unique — uniqueness by
    /// well-known id, fetch before insert).
    static func userConfig(in context: ModelContext) -> UserConfig {
        let wellKnown = UserConfig.wellKnownID
        var descriptor = FetchDescriptor<UserConfig>(predicate: #Predicate { $0.id == wellKnown })
        descriptor.fetchLimit = 1
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let fresh = UserConfig()
        context.insert(fresh)
        return fresh
    }

    /// All launcher cards, launcher order. Card 1 is Home's card.
    static func cards(in context: ModelContext) -> [LauncherCard] {
        let descriptor = FetchDescriptor<LauncherCard>(sortBy: [SortDescriptor(\.sortOrder)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// The custom-entry registry (v1.6: EssentialApp's only remaining role).
    static func customEntries(in context: ModelContext) -> [EssentialApp] {
        let descriptor = FetchDescriptor<EssentialApp>(sortBy: [SortDescriptor(\.sortOrder)])
        return ((try? context.fetch(descriptor)) ?? []).filter { CustomSlug.isCustom($0.slug) }
    }

    /// Fetch-or-create the default BlockList.
    static func defaultBlockList(in context: ModelContext) -> BlockList {
        var descriptor = FetchDescriptor<BlockList>(predicate: #Predicate { $0.isDefault })
        descriptor.fetchLimit = 1
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let fresh = BlockList()
        context.insert(fresh)
        return fresh
    }
}
