import SwiftData
import XCTest
@testable import Minus

@MainActor
final class SessionCoordinatorTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var mock: MockScreenTimeService!
    private var coordinator: SessionCoordinator!
    private var blockList: BlockList!
    private var frozenNow: Date!

    override func setUp() async throws {
        SharedState.reset()
        frozenNow = Date(timeIntervalSince1970: 1_772_000_000)
        // Capture self (not the value) so tests can advance frozenNow mid-test;
        // tearDown resets ClockProvider, releasing the capture.
        ClockProvider.now = { self.frozenNow }
        container = MinusContainer.make(inMemory: true)
        context = container.mainContext
        mock = MockScreenTimeService()
        coordinator = SessionCoordinator(service: mock, context: context)
        blockList = MinusContainer.defaultBlockList(in: context)
        blockList.selectionData = MockScreenTimeService.encodeSelection(apps: 3, categories: 1)
    }

    override func tearDown() async throws {
        SharedState.reset()
        ClockProvider.now = { Date() }
    }

    private func fetchSessions() -> [FocusSession] {
        (try? context.fetch(FetchDescriptor<FocusSession>())) ?? []
    }

    // MARK: Start

    func testStartAppliesShieldsAndPersists() throws {
        let session = try coordinator.start(minutes: 30, blockList: blockList)
        XCTAssertTrue(mock.shieldedActivities.contains(session.activityName))
        XCTAssertEqual(SharedState.activeSessions.count, 1)
        XCTAssertEqual(coordinator.activeSnapshot?.sessionID, session.id)
        XCTAssertEqual(session.plannedEndAt, frozenNow.addingTimeInterval(30 * 60))
        XCTAssertEqual(coordinator.remaining, 30 * 60)
        XCTAssertEqual(fetchSessions().count, 1)
    }

    func testStartWhileActiveThrows() throws {
        try coordinator.start(minutes: 30, blockList: blockList)
        XCTAssertThrowsError(try coordinator.start(minutes: 30, blockList: blockList)) { error in
            XCTAssertEqual(error as? SessionCoordinator.StartError, .alreadyActive)
        }
    }

    func testStartUnder15MinutesThrows() {
        XCTAssertThrowsError(try coordinator.start(minutes: 14, blockList: blockList)) { error in
            XCTAssertEqual(error as? SessionCoordinator.StartError, .tooShort)
        }
    }

    func testStartWithoutSelectionThrows() {
        blockList.selectionData = nil
        XCTAssertThrowsError(try coordinator.start(minutes: 30, blockList: blockList)) { error in
            XCTAssertEqual(error as? SessionCoordinator.StartError, .noBlockList)
        }
    }

    // MARK: End

    func testEndEarlyClearsEverythingAndMarksReason() throws {
        let session = try coordinator.start(minutes: 30, blockList: blockList)
        coordinator.endEarly()
        XCTAssertFalse(mock.shieldedActivities.contains(session.activityName))
        XCTAssertTrue(SharedState.activeSessions.isEmpty)
        XCTAssertNil(coordinator.activeSnapshot)
        let stored = fetchSessions().first
        XCTAssertEqual(stored?.endReason, .endedEarly)
        XCTAssertEqual(stored?.endedAt, frozenNow)
    }

    func testReconcileDrainsLedgerAndCompletesSession() throws {
        let session = try coordinator.start(minutes: 30, blockList: blockList)
        // Simulate the monitor extension having fired while we were dead.
        let endDate = frozenNow.addingTimeInterval(30 * 60)
        SharedState.appendPendingEvent(MonitorEvent(kind: .intervalEnded, activityName: session.activityName, date: endDate))
        coordinator.reconcile()
        XCTAssertNil(coordinator.activeSnapshot)
        XCTAssertTrue(SharedState.activeSessions.isEmpty)
        let stored = fetchSessions().first
        XCTAssertEqual(stored?.endReason, .completed)
        XCTAssertEqual(stored?.endedAt, endDate)
    }

    func testReconcileSweepsStaleSnapshot() throws {
        let session = try coordinator.start(minutes: 30, blockList: blockList)
        // Clock jumps past the planned end with no ledger event (missed callback).
        frozenNow = frozenNow.addingTimeInterval(45 * 60)
        coordinator.reconcile()
        XCTAssertNil(coordinator.activeSnapshot)
        XCTAssertFalse(mock.shieldedActivities.contains(session.activityName))
        let stored = fetchSessions().first
        XCTAssertEqual(stored?.endReason, .completed)
        XCTAssertEqual(stored?.endedAt, stored?.plannedEndAt)
    }

    func testScheduleEventsDoNotCloseManualSessions() throws {
        try coordinator.start(minutes: 30, blockList: blockList)
        SharedState.appendPendingEvent(MonitorEvent(kind: .intervalEnded, activityName: "schedule-X-w2", date: frozenNow))
        coordinator.reconcile()
        XCTAssertNotNil(coordinator.activeSnapshot)
        XCTAssertEqual(fetchSessions().first?.endedAt, nil)
    }

    // MARK: Schedules

    private func makeSchedule(weekdays: [Int] = [2, 3]) -> FocusSchedule {
        let schedule = FocusSchedule(name: "Deep work", weekdays: weekdays, startMinuteOfDay: 540, endMinuteOfDay: 660)
        context.insert(schedule)
        return schedule
    }

    func testRegisterScheduleWritesRegistry() throws {
        let schedule = makeSchedule()
        try coordinator.register(schedule: schedule, blockList: blockList)
        XCTAssertEqual(SharedState.scheduleRegistry.count, 2)
        let names = Set(SharedState.scheduleRegistry.keys)
        XCTAssertTrue(names.contains(ScheduleMath.activityName(scheduleID: schedule.id, weekday: 2)))
        XCTAssertTrue(names.contains(ScheduleMath.activityName(scheduleID: schedule.id, weekday: 3)))
    }

    func testRegisterOverBudgetThrows() throws {
        var registry = SharedState.scheduleRegistry
        for i in 0..<18 {
            registry["fake-\(i)"] = RegisteredInterval(
                activityName: "fake-\(i)", scheduleID: UUID(), selectionData: Data(),
                weekday: 1, startMinuteOfDay: 0, endMinuteOfDay: 60
            )
        }
        SharedState.scheduleRegistry = registry
        let schedule = makeSchedule(weekdays: [2, 3])
        XCTAssertThrowsError(try coordinator.register(schedule: schedule, blockList: blockList))
    }

    func testUnregisterRemovesOnlyThatSchedule() throws {
        let a = makeSchedule(weekdays: [2])
        let b = makeSchedule(weekdays: [3])
        try coordinator.register(schedule: a, blockList: blockList)
        try coordinator.register(schedule: b, blockList: blockList)
        coordinator.unregister(schedule: a)
        XCTAssertEqual(SharedState.scheduleRegistry.count, 1)
        XCTAssertNotNil(SharedState.scheduleRegistry[ScheduleMath.activityName(scheduleID: b.id, weekday: 3)])
    }

    // MARK: Reset

    func testResetAllWipesSessionsAndRegistry() throws {
        let session = try coordinator.start(minutes: 30, blockList: blockList)
        let schedule = makeSchedule()
        try coordinator.register(schedule: schedule, blockList: blockList)
        coordinator.resetAll()
        XCTAssertTrue(SharedState.activeSessions.isEmpty)
        XCTAssertTrue(SharedState.scheduleRegistry.isEmpty)
        XCTAssertFalse(mock.shieldedActivities.contains(session.activityName))
        XCTAssertNil(coordinator.activeSnapshot)
    }
}
