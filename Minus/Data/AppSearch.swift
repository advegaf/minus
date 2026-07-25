import Foundation

/// Turning an app's NAME into its identity, so any app on the phone can join a
/// card, not just the sixty minus ships with.
///
/// iOS refuses to enumerate installed apps, so minus cannot present a list of
/// what you own. But it can resolve what you ask for: Apple's public iTunes
/// Search endpoint answers a name with a bundle identifier, needs no key, and
/// covers the whole store. Verified against the catalog's own hand-written
/// identifiers, which it reproduced exactly.
///
/// The network is touched ONCE, when adding. After that the identity is
/// stored and every launch is offline.
enum AppSearch {
    struct Match: Identifiable, Equatable, Sendable {
        var name: String
        var seller: String
        var bundleID: String

        var id: String { bundleID }
    }

    enum Failure: Error, Equatable {
        case offline
        case nothingFound
    }

    /// Apps matching `term`, best first. Empty terms return nothing rather
    /// than everything.
    static func matches(for term: String, limit: Int = 10) async throws -> [Match] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        #if DEBUG
        // The only network call in the app, so the only thing a UI test cannot
        // ask for honestly. MINUS_SEARCH answers in its place: `stub` for the
        // happy path, `offline` and `empty` for the two failures whose copy
        // would otherwise never be seen until a user hit them.
        switch ProcessInfo.processInfo.environment["MINUS_SEARCH"] {
        case "stub":
            return [
                Match(name: "Pilates Studio - Reformer & Mat Classes", seller: "Studio Software", bundleID: "com.example.pilates"),
                Match(name: "Pilates Daily", seller: "Daily Apps", bundleID: "com.example.pilatesdaily"),
            ]
        case "offline":
            throw Failure.offline
        case "empty":
            throw Failure.nothingFound
        default:
            break
        }
        #endif

        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: trimmed),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "country", value: storefront),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        guard let url = components?.url else { return [] }

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(from: url)
        } catch {
            throw Failure.offline
        }

        let decoded = try? JSONDecoder().decode(Response.self, from: data)
        let results = (decoded?.results ?? []).compactMap { row -> Match? in
            guard let bundleID = row.bundleId, !bundleID.isEmpty,
                  let name = row.trackName, !name.isEmpty else { return nil }
            return Match(name: name, seller: row.artistName ?? "", bundleID: bundleID)
        }
        if results.isEmpty { throw Failure.nothingFound }
        return results
    }

    /// The store to search. A French user asking for "Deliveroo" should get
    /// the app their phone actually has.
    private static var storefront: String {
        Locale.current.region?.identifier.lowercased() ?? "us"
    }

    private struct Response: Decodable {
        var results: [Row]
    }

    private struct Row: Decodable {
        var trackName: String?
        var artistName: String?
        var bundleId: String?
    }
}
