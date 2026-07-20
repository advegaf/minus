import Foundation

/// Pure stat derivation over FocusSession value snapshots — "derive live,
/// never materialize". Sessions are passed as lightweight values so the engine
/// stays SwiftData-free and unit-testable.
struct SessionSlice: Sendable, Equatable {
    var startedAt: Date
    var endedAt: Date?
    var plannedEndAt: Date
    var wasCompleted: Bool

    init(startedAt: Date, endedAt: Date?, plannedEndAt: Date, wasCompleted: Bool) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedEndAt = plannedEndAt
        self.wasCompleted = wasCompleted
    }
}

enum StatsService {
    /// Seconds of focus overlapping a given day. Active sessions count up to
    /// `now`; ended sessions up to their end.
    static func focusSeconds(on day: Date, sessions: [SessionSlice], now: Date, calendar: Calendar = .current) -> TimeInterval {
        guard let dayStart = calendar.dateInterval(of: .day, for: day)?.start,
              let dayEnd = calendar.dateInterval(of: .day, for: day)?.end else { return 0 }
        return sessions.reduce(0) { total, session in
            let effectiveEnd = session.endedAt ?? min(now, session.plannedEndAt)
            let overlapStart = max(session.startedAt, dayStart)
            let overlapEnd = min(effectiveEnd, dayEnd)
            return total + max(0, overlapEnd.timeIntervalSince(overlapStart))
        }
    }

    /// Seconds of focus in the 7 days ending on (and including) `day`.
    static func weekSeconds(ending day: Date, sessions: [SessionSlice], now: Date, calendar: Calendar = .current) -> TimeInterval {
        (0..<7).reduce(0) { total, offset in
            guard let d = calendar.date(byAdding: .day, value: -offset, to: day) else { return total }
            return total + focusSeconds(on: d, sessions: sessions, now: now, calendar: calendar)
        }
    }

    static func sessionsCompleted(on day: Date, sessions: [SessionSlice], calendar: Calendar = .current) -> Int {
        sessions.filter { session in
            guard session.wasCompleted, let end = session.endedAt else { return false }
            return calendar.isDate(end, inSameDayAs: day)
        }.count
    }

    /// Short human duration ("1h 24m", "24m", "0m").
    static func shortDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes >= 60 {
            let remainder = minutes % 60
            return remainder == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(remainder)m"
        }
        return "\(minutes)m"
    }
}

enum StreakService {
    /// Consecutive days (ending today or yesterday) with at least one
    /// completed session. A today without a session yet does NOT break the
    /// streak — it's pending until the day ends.
    static func currentStreak(sessions: [SessionSlice], today: Date, calendar: Calendar = .current) -> Int {
        let completedDays: Set<Date> = Set(
            sessions.compactMap { session -> Date? in
                guard session.wasCompleted, let end = session.endedAt else { return nil }
                return calendar.startOfDay(for: end)
            }
        )
        var streak = 0
        var cursor = calendar.startOfDay(for: today)
        if !completedDays.contains(cursor) {
            // Today pending — start counting from yesterday.
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        while completedDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
