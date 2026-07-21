import XCTest
@testable import Minus

final class DeepLinkTests: XCTestCase {
    private func parse(_ s: String) -> DeepLink? {
        URL(string: s).flatMap(DeepLink.parse)
    }

    func testOpenEssential() {
        XCTAssertEqual(parse("minus://open/messages"), .openEssential(slug: "messages"))
        XCTAssertEqual(parse("minus://open/phone"), .openEssential(slug: "phone"))
    }

    func testFocus() {
        XCTAssertEqual(parse("minus://focus"), .focus)
    }

    func testRejects() {
        XCTAssertNil(parse("minus://open"))
        XCTAssertNil(parse("minus://open/"))
        XCTAssertNil(parse("minus://something"))
        XCTAssertNil(parse("https://open/messages"))
        XCTAssertNil(parse("minus://"))
    }
}

@MainActor
final class LauncherBridgeTests: XCTestCase {
    func testSnapshotBuilder() {
        let essentials = [
            EssentialApp(slug: "phone", displayName: "Phone", urlScheme: "tel:", sortOrder: 0),
            EssentialApp(slug: "messages", displayName: "Messages", urlScheme: "sms:", sortOrder: 1),
        ]
        let schedule = FocusSchedule(name: "Deep work", weekdays: [2], startMinuteOfDay: 540, endMinuteOfDay: 660)
        let now = Date(timeIntervalSince1970: 1_772_000_000)
        let active = ActivitySnapshot(
            activityName: "session-X", sessionID: UUID(),
            startedAt: now, plannedEndAt: now.addingTimeInterval(1500)
        )

        let snapshot = LauncherBridge.snapshot(
            essentials: essentials,
            intention: "less phone. more life.",
            activeSnapshot: active,
            schedules: [schedule],
            now: now,
            installedCheck: { $0.scheme == "tel" }
        )

        XCTAssertEqual(snapshot.essentials.map(\.slug), ["phone", "messages"])
        XCTAssertEqual(snapshot.essentials[0].installed, true)
        XCTAssertEqual(snapshot.essentials[1].installed, false)
        XCTAssertEqual(snapshot.intention, "less phone. more life.")
        XCTAssertEqual(snapshot.focus.activeUntil, active.plannedEndAt)
        XCTAssertNotNil(snapshot.focus.nextSchedule)
        XCTAssertTrue(snapshot.focus.nextSchedule!.hasPrefix("next · deep work · "))
        XCTAssertEqual(snapshot.generatedAt, now)
    }

    func testSnapshotRoundTrip() {
        let original = LauncherSnapshot.fixture
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try! encoder.encode(original)
        let decoded = try! decoder.decode(LauncherSnapshot.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
