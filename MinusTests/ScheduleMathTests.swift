import XCTest
@testable import Minus

final class ScheduleMathTests: XCTestCase {
    private let id = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!

    // MARK: Validation

    func testValidWindowPasses() {
        XCTAssertNil(ScheduleMath.validate(weekdays: [2], startMinuteOfDay: 540, endMinuteOfDay: 660, existingRegistrationCount: 0))
    }

    func testWindowUnder15MinutesRejected() {
        XCTAssertEqual(
            ScheduleMath.validate(weekdays: [2], startMinuteOfDay: 540, endMinuteOfDay: 554, existingRegistrationCount: 0),
            .windowTooShort
        )
    }

    func testExactly15MinutesPasses() {
        XCTAssertNil(ScheduleMath.validate(weekdays: [2], startMinuteOfDay: 540, endMinuteOfDay: 555, existingRegistrationCount: 0))
    }

    func testCrossMidnightRejected() {
        XCTAssertEqual(
            ScheduleMath.validate(weekdays: [2], startMinuteOfDay: 1380, endMinuteOfDay: 60, existingRegistrationCount: 0),
            .crossesMidnight
        )
    }

    /// The window people reach for when they want everything blocked: the
    /// whole day, every day, looping into the next one.
    func testAllDayWindowIsValid() {
        XCTAssertNil(
            ScheduleMath.validate(
                weekdays: [1, 2, 3, 4, 5, 6, 7],
                startMinuteOfDay: 0,
                endMinuteOfDay: 1439,
                existingRegistrationCount: 0
            )
        )
        XCTAssertTrue(ScheduleMath.isAllDay(startMinuteOfDay: 0, endMinuteOfDay: 1439))
        XCTAssertFalse(ScheduleMath.isAllDay(startMinuteOfDay: 0, endMinuteOfDay: 1438))
    }

    /// A window ending on the last minute runs to :59, so the next day picks
    /// up a second later instead of leaving a minute of the night open.
    func testAllDayWindowEndsOnTheLastSecond() {
        XCTAssertEqual(ScheduleMath.endSecond(forEndMinuteOfDay: 1439), 59)
        XCTAssertEqual(ScheduleMath.endSecond(forEndMinuteOfDay: 660), 0)
    }

    /// 1440 is not a minute of any day: it expands to hour 24, which no
    /// DateComponents can carry.
    func testEndPastTheDayRejected() {
        XCTAssertEqual(
            ScheduleMath.validate(
                weekdays: [2],
                startMinuteOfDay: 0,
                endMinuteOfDay: 1440,
                existingRegistrationCount: 0
            ),
            .endPastMidnight
        )
    }

    func testNoWeekdaysRejected() {
        XCTAssertEqual(
            ScheduleMath.validate(weekdays: [], startMinuteOfDay: 540, endMinuteOfDay: 660, existingRegistrationCount: 0),
            .noWeekdays
        )
    }

    func testBudgetOverflowRejected() {
        XCTAssertEqual(
            ScheduleMath.validate(weekdays: [1, 2, 3], startMinuteOfDay: 540, endMinuteOfDay: 660, existingRegistrationCount: 17),
            .overBudget
        )
        XCTAssertNil(
            ScheduleMath.validate(weekdays: [1, 2], startMinuteOfDay: 540, endMinuteOfDay: 660, existingRegistrationCount: 17)
        )
    }

    // MARK: Expansion

    func testExpansionProducesOneEntryPerWeekdaySorted() {
        let expansions = ScheduleMath.expansions(scheduleID: id, weekdays: [6, 2, 4], startMinuteOfDay: 555, endMinuteOfDay: 675)
        XCTAssertEqual(expansions.map(\.weekday), [2, 4, 6])
        XCTAssertEqual(expansions[0].activityName, "schedule-\(id.uuidString)-w2")
        XCTAssertEqual(expansions[0].start.hour, 9)
        XCTAssertEqual(expansions[0].start.minute, 15)
        XCTAssertEqual(expansions[0].end.hour, 11)
        XCTAssertEqual(expansions[0].end.minute, 15)
        XCTAssertEqual(expansions[0].start.weekday, 2)
    }

    func testActivityNameClassification() {
        XCTAssertTrue(ScheduleMath.isScheduleActivity("schedule-X-w2"))
        XCTAssertFalse(ScheduleMath.isScheduleActivity(ScheduleMath.manualActivityName(sessionID: id)))
    }

    // MARK: Overlap

    func testOverlapRequiresSharedWeekday() {
        XCTAssertFalse(ScheduleMath.overlaps((weekdays: [2], start: 540, end: 660), (weekdays: [3], start: 540, end: 660)))
        XCTAssertTrue(ScheduleMath.overlaps((weekdays: [2, 3], start: 540, end: 660), (weekdays: [3], start: 600, end: 720)))
    }

    func testAdjacentWindowsDoNotOverlap() {
        XCTAssertFalse(ScheduleMath.overlaps((weekdays: [2], start: 540, end: 660), (weekdays: [2], start: 660, end: 780)))
    }

    // MARK: Occurrence / activity

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func testNextOccurrencePicksEarliestWeekday() {
        // Thu 2026-01-01 12:00 UTC.
        let reference = Date(timeIntervalSince1970: 1_767_268_800)
        let next = ScheduleMath.nextOccurrence(weekdays: [6, 2], startMinuteOfDay: 540, after: reference, calendar: utcCalendar)
        // Next Fri (weekday 6) is Jan 2, before next Mon (weekday 2) Jan 5.
        let expected = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 9))!
        XCTAssertEqual(next, expected)
    }

    func testIsActiveBoundaries() {
        // Mon 2026-01-05 09:00 UTC exactly.
        let monday9 = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 9))!
        XCTAssertTrue(ScheduleMath.isActive(weekdays: [2], startMinuteOfDay: 540, endMinuteOfDay: 660, at: monday9, calendar: utcCalendar))
        // End is exclusive.
        let monday11 = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 11))!
        XCTAssertFalse(ScheduleMath.isActive(weekdays: [2], startMinuteOfDay: 540, endMinuteOfDay: 660, at: monday11, calendar: utcCalendar))
        // Wrong weekday.
        let tuesday10 = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 6, hour: 10))!
        XCTAssertFalse(ScheduleMath.isActive(weekdays: [2], startMinuteOfDay: 540, endMinuteOfDay: 660, at: tuesday10, calendar: utcCalendar))
    }
}
