import XCTest
@testable import Minus

final class StatsEngineTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour, minute: minute))!
    }

    // MARK: StatsService

    func testFocusSecondsSimpleSession() {
        let sessions = [SessionSlice(startedAt: date(10, 9), endedAt: date(10, 10), plannedEndAt: date(10, 10), wasCompleted: true)]
        XCTAssertEqual(StatsService.focusSeconds(on: date(10, 12), sessions: sessions, now: date(10, 20), calendar: calendar), 3600)
    }

    func testFocusSecondsSplitsAcrossMidnight() {
        let sessions = [SessionSlice(startedAt: date(10, 23), endedAt: date(11, 1), plannedEndAt: date(11, 1), wasCompleted: true)]
        XCTAssertEqual(StatsService.focusSeconds(on: date(10, 12), sessions: sessions, now: date(12, 0), calendar: calendar), 3600)
        XCTAssertEqual(StatsService.focusSeconds(on: date(11, 12), sessions: sessions, now: date(12, 0), calendar: calendar), 3600)
    }

    func testActiveSessionCountsUpToNow() {
        let sessions = [SessionSlice(startedAt: date(10, 9), endedAt: nil, plannedEndAt: date(10, 11), wasCompleted: false)]
        XCTAssertEqual(StatsService.focusSeconds(on: date(10, 12), sessions: sessions, now: date(10, 9, 30), calendar: calendar), 1800)
        // Never counts past plannedEnd even if now is later (stale snapshot).
        XCTAssertEqual(StatsService.focusSeconds(on: date(10, 12), sessions: sessions, now: date(10, 15), calendar: calendar), 7200)
    }

    func testWeekSecondsAggregatesSevenDays() {
        let sessions = [
            SessionSlice(startedAt: date(8, 9), endedAt: date(8, 10), plannedEndAt: date(8, 10), wasCompleted: true),
            SessionSlice(startedAt: date(14, 9), endedAt: date(14, 9, 30), plannedEndAt: date(14, 9, 30), wasCompleted: true),
            // Outside the window (8 days before the 14th).
            SessionSlice(startedAt: date(6, 9), endedAt: date(6, 10), plannedEndAt: date(6, 10), wasCompleted: true),
        ]
        XCTAssertEqual(StatsService.weekSeconds(ending: date(14, 20), sessions: sessions, now: date(14, 22), calendar: calendar), 5400)
    }

    func testSessionsCompletedOnDay() {
        let sessions = [
            SessionSlice(startedAt: date(10, 9), endedAt: date(10, 10), plannedEndAt: date(10, 10), wasCompleted: true),
            SessionSlice(startedAt: date(10, 11), endedAt: date(10, 11, 30), plannedEndAt: date(10, 12), wasCompleted: false),
            SessionSlice(startedAt: date(9, 9), endedAt: date(9, 10), plannedEndAt: date(9, 10), wasCompleted: true),
        ]
        XCTAssertEqual(StatsService.sessionsCompleted(on: date(10, 23), sessions: sessions, calendar: calendar), 1)
    }

    func testShortDurationFormatting() {
        XCTAssertEqual(StatsService.shortDuration(0), "0m")
        XCTAssertEqual(StatsService.shortDuration(24 * 60), "24m")
        XCTAssertEqual(StatsService.shortDuration(60 * 60), "1h")
        XCTAssertEqual(StatsService.shortDuration(84 * 60), "1h 24m")
    }

    // MARK: StreakService

    private func completed(on day: Int) -> SessionSlice {
        SessionSlice(startedAt: date(day, 9), endedAt: date(day, 10), plannedEndAt: date(day, 10), wasCompleted: true)
    }

    func testEmptyStreakIsZero() {
        XCTAssertEqual(StreakService.currentStreak(sessions: [], today: date(10, 12), calendar: calendar), 0)
    }

    func testTodayCompletedCountsOne() {
        XCTAssertEqual(StreakService.currentStreak(sessions: [completed(on: 10)], today: date(10, 12), calendar: calendar), 1)
    }

    func testTodayPendingDoesNotBreakStreak() {
        let sessions = [completed(on: 9), completed(on: 8)]
        XCTAssertEqual(StreakService.currentStreak(sessions: sessions, today: date(10, 12), calendar: calendar), 2)
    }

    func testChainCountsConsecutiveDays() {
        let sessions = [completed(on: 10), completed(on: 9), completed(on: 8), completed(on: 6)]
        XCTAssertEqual(StreakService.currentStreak(sessions: sessions, today: date(10, 12), calendar: calendar), 3)
    }

    func testGapBeforeYesterdayBreaks() {
        let sessions = [completed(on: 7), completed(on: 6)]
        XCTAssertEqual(StreakService.currentStreak(sessions: sessions, today: date(10, 12), calendar: calendar), 0)
    }
}
