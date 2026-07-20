import XCTest
@testable import Minus

final class SharedStateTests: XCTestCase {
    override func setUp() {
        SharedState.reset()
    }

    override func tearDown() {
        SharedState.reset()
    }

    func testActiveSessionsRoundTrip() {
        let snapshot = ActivitySnapshot(
            activityName: "session-X",
            sessionID: UUID(),
            startedAt: Date(timeIntervalSince1970: 1_000_000),
            plannedEndAt: Date(timeIntervalSince1970: 1_001_800)
        )
        SharedState.activeSessions = [snapshot]
        XCTAssertEqual(SharedState.activeSessions.first?.activityName, "session-X")
        SharedState.removeActiveSession(activityName: "session-X")
        XCTAssertTrue(SharedState.activeSessions.isEmpty)
    }

    func testScheduleRegistryRoundTrip() {
        let interval = RegisteredInterval(
            activityName: "schedule-A-w2", scheduleID: UUID(), selectionData: Data([1, 2, 3]),
            weekday: 2, startMinuteOfDay: 540, endMinuteOfDay: 660
        )
        SharedState.scheduleRegistry = ["schedule-A-w2": interval]
        XCTAssertEqual(SharedState.scheduleRegistry["schedule-A-w2"]?.selectionData, Data([1, 2, 3]))
    }

    func testPendingEventsDrainClears() {
        SharedState.appendPendingEvent(MonitorEvent(kind: .intervalEnded, activityName: "a", date: .now))
        SharedState.appendPendingEvent(MonitorEvent(kind: .intervalStarted, activityName: "b", date: .now))
        let drained = SharedState.drainPendingEvents()
        XCTAssertEqual(drained.map(\.activityName), ["a", "b"])
        XCTAssertTrue(SharedState.drainPendingEvents().isEmpty)
    }

    func testMonitorLogRingBufferCapsAt200() {
        for i in 0..<230 {
            SharedState.appendMonitorLog("line \(i)")
        }
        let log = SharedState.monitorLog
        XCTAssertEqual(log.count, 200)
        XCTAssertEqual(log.first, "line 30")
        XCTAssertEqual(log.last, "line 229")
    }

    func testResetClearsEverything() {
        SharedState.activeSessions = [
            ActivitySnapshot(activityName: "x", sessionID: UUID(), startedAt: .now, plannedEndAt: .now)
        ]
        SharedState.appendMonitorLog("line")
        SharedState.reset()
        XCTAssertTrue(SharedState.activeSessions.isEmpty)
        XCTAssertTrue(SharedState.monitorLog.isEmpty)
    }
}
