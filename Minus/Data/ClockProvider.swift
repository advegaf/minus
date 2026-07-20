import Foundation

/// Injectable time source so screenshots and UI tests are deterministic.
/// `MINUS_FREEZE_TIME=HH:mm` (DEBUG) pins the clock to today at that time.
@MainActor
enum ClockProvider {
    static var now: () -> Date = { Date() }

    static func configureFromEnvironment() {
        #if DEBUG
        guard let raw = ProcessInfo.processInfo.environment["MINUS_FREEZE_TIME"] else { return }
        let parts = raw.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = parts[0]
        components.minute = parts[1]
        if let frozen = Calendar.current.date(from: components) {
            now = { frozen }
        }
        #endif
    }
}
