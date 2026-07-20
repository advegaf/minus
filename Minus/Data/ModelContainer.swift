import Foundation
import SwiftData

enum MinusSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [UserConfig.self, EssentialApp.self, BlockList.self, FocusSession.self, FocusSchedule.self]
    }
}

@MainActor
enum MinusContainer {
    static func make(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(versionedSchema: MinusSchemaV1.self)
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
