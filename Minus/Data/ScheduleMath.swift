import Foundation

/// Pure schedule arithmetic — no SwiftData, no DeviceActivity imports, fully
/// unit-testable in milliseconds.
enum ScheduleMath {
    /// DeviceActivity rejects intervals under 15 minutes.
    static let minimumWindowMinutes = 15
    /// DeviceActivityCenter caps concurrently monitored activities (~20).
    /// Budget: 1 manual-session slot + 19 schedule slots.
    static let activityBudget = 19

    /// One DeviceActivity registration per (schedule, weekday).
    static func activityName(scheduleID: UUID, weekday: Int) -> String {
        "schedule-\(scheduleID.uuidString)-w\(weekday)"
    }

    static func manualActivityName(sessionID: UUID) -> String {
        "session-\(sessionID.uuidString)"
    }

    static func isScheduleActivity(_ name: String) -> Bool {
        name.hasPrefix("schedule-")
    }

    /// Weekday windows a schedule expands to.
    static func expansions(scheduleID: UUID, weekdays: [Int], startMinuteOfDay: Int, endMinuteOfDay: Int) -> [(activityName: String, weekday: Int, start: DateComponents, end: DateComponents)] {
        weekdays.sorted().map { weekday in
            var start = DateComponents()
            start.weekday = weekday
            start.hour = startMinuteOfDay / 60
            start.minute = startMinuteOfDay % 60
            var end = DateComponents()
            end.weekday = weekday
            end.hour = endMinuteOfDay / 60
            end.minute = endMinuteOfDay % 60
            return (activityName(scheduleID: scheduleID, weekday: weekday), weekday, start, end)
        }
    }

    enum ValidationError: Equatable, Sendable {
        case windowTooShort
        case crossesMidnight
        case noWeekdays
        case overBudget
    }

    /// v1 rules: same-day window, ≥15 minutes, at least one weekday, and the
    /// expansion must fit the activity budget alongside existing registrations.
    static func validate(weekdays: [Int], startMinuteOfDay: Int, endMinuteOfDay: Int, existingRegistrationCount: Int) -> ValidationError? {
        if weekdays.isEmpty { return .noWeekdays }
        if endMinuteOfDay <= startMinuteOfDay { return .crossesMidnight }
        if endMinuteOfDay - startMinuteOfDay < minimumWindowMinutes { return .windowTooShort }
        if existingRegistrationCount + weekdays.count > activityBudget { return .overBudget }
        return nil
    }

    /// True when two same-weekday windows intersect.
    static func overlaps(_ a: (weekdays: [Int], start: Int, end: Int), _ b: (weekdays: [Int], start: Int, end: Int)) -> Bool {
        guard !Set(a.weekdays).isDisjoint(with: b.weekdays) else { return false }
        return a.start < b.end && b.start < a.end
    }

    /// Next wall-clock start of a schedule after a reference date.
    static func nextOccurrence(weekdays: [Int], startMinuteOfDay: Int, after reference: Date, calendar: Calendar = .current) -> Date? {
        guard !weekdays.isEmpty else { return nil }
        var best: Date?
        for weekday in weekdays {
            var components = DateComponents()
            components.weekday = weekday
            components.hour = startMinuteOfDay / 60
            components.minute = startMinuteOfDay % 60
            if let next = calendar.nextDate(after: reference, matching: components, matchingPolicy: .nextTime) {
                best = best.map { min($0, next) } ?? next
            }
        }
        return best
    }

    /// Whether a schedule window contains the given date.
    static func isActive(weekdays: [Int], startMinuteOfDay: Int, endMinuteOfDay: Int, at date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        guard weekdays.contains(weekday) else { return false }
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        return minute >= startMinuteOfDay && minute < endMinuteOfDay
    }
}
