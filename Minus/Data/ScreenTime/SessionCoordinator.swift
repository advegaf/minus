import Foundation
import SwiftData

/// Session lifecycle orchestration — the single writer for shields, activity
/// registration, SharedState, and FocusSession rows.
///
/// Trust invariants:
/// 1. Shields applied in-app at start (instant), extension is only the janitor.
/// 2. Every started session has a one-shot end timer so intervalDidEnd clears
///    shields even if the app dies.
/// 3. reconcile() on every foreground drains the extension's ledger AND
///    sweeps any snapshot past its planned end — belt and braces.
@MainActor
@Observable
final class SessionCoordinator {
    enum StartError: Error, Equatable {
        case alreadyActive
        case tooShort
        case noBlockList
        case monitoringFailed(String)
    }

    let service: any ScreenTimeService
    private let context: ModelContext
    private(set) var activeSnapshot: ActivitySnapshot?

    init(service: any ScreenTimeService, context: ModelContext) {
        self.service = service
        self.context = context
        activeSnapshot = SharedState.activeSessions.first
        NotificationCenter.default.addObserver(
            forName: .minusMockIntervalEnded, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reconcile()
            }
        }
    }

    // MARK: Manual sessions

    var isSessionActive: Bool { activeSnapshot != nil }

    var remaining: TimeInterval? {
        activeSnapshot.map { max(0, $0.plannedEndAt.timeIntervalSince(ClockProvider.now())) }
    }

    @discardableResult
    func start(minutes: Int, blockList: BlockList) throws -> FocusSession {
        guard activeSnapshot == nil else { throw StartError.alreadyActive }
        guard minutes >= ScheduleMath.minimumWindowMinutes else { throw StartError.tooShort }
        guard blockList.selectionData != nil else { throw StartError.noBlockList }

        let now = ClockProvider.now()
        let end = now.addingTimeInterval(TimeInterval(minutes * 60))
        let session = FocusSession(startedAt: now, plannedEndAt: end, source: .manual, activityName: "")
        session.activityName = ScheduleMath.manualActivityName(sessionID: session.id)

        service.applyShields(selectionData: blockList.selectionData, activityName: session.activityName)
        do {
            try service.startEndTimer(activityName: session.activityName, from: now, to: end)
        } catch {
            service.clearShields(activityName: session.activityName)
            throw StartError.monitoringFailed(String(describing: error))
        }

        context.insert(session)
        try? context.save()

        let snapshot = ActivitySnapshot(
            activityName: session.activityName,
            sessionID: session.id,
            startedAt: now,
            plannedEndAt: end
        )
        SharedState.activeSessions = [snapshot]
        activeSnapshot = snapshot
        return session
    }

    func endEarly() {
        guard let snapshot = activeSnapshot else { return }
        service.clearShields(activityName: snapshot.activityName)
        service.stopActivities([snapshot.activityName])
        closeSession(activityName: snapshot.activityName, at: ClockProvider.now(), reason: .endedEarly)
        SharedState.removeActiveSession(activityName: snapshot.activityName)
        activeSnapshot = nil
    }

    // MARK: Reconcile (foreground + mock end signal)

    func reconcile() {
        // 1. Drain the extension's ledger.
        for event in SharedState.drainPendingEvents() where event.kind == .intervalEnded {
            if !ScheduleMath.isScheduleActivity(event.activityName) {
                closeSession(activityName: event.activityName, at: event.date, reason: .completed)
                SharedState.removeActiveSession(activityName: event.activityName)
            }
        }
        // 2. Sweep anything past its planned end the ledger missed.
        let now = ClockProvider.now()
        for snapshot in SharedState.activeSessions where snapshot.plannedEndAt <= now {
            service.clearShields(activityName: snapshot.activityName)
            service.stopActivities([snapshot.activityName])
            closeSession(activityName: snapshot.activityName, at: snapshot.plannedEndAt, reason: .completed)
            SharedState.removeActiveSession(activityName: snapshot.activityName)
        }
        activeSnapshot = SharedState.activeSessions.first
    }

    private func closeSession(activityName: String, at date: Date, reason: SessionEndReason) {
        var descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.activityName == activityName && $0.endedAt == nil }
        )
        descriptor.fetchLimit = 1
        guard let session = (try? context.fetch(descriptor))?.first else { return }
        session.endedAt = date
        session.endReason = reason
        try? context.save()
    }

    // MARK: Schedules

    func register(schedule: FocusSchedule, blockList: BlockList) throws {
        guard let selectionData = blockList.selectionData else { throw StartError.noBlockList }
        if let error = ScheduleMath.validate(
            weekdays: schedule.weekdays,
            startMinuteOfDay: schedule.startMinuteOfDay,
            endMinuteOfDay: schedule.endMinuteOfDay,
            existingRegistrationCount: SharedState.scheduleRegistry.count
        ) {
            throw StartError.monitoringFailed(String(describing: error))
        }
        var registry = SharedState.scheduleRegistry
        for expansion in ScheduleMath.expansions(
            scheduleID: schedule.id,
            weekdays: schedule.weekdays,
            startMinuteOfDay: schedule.startMinuteOfDay,
            endMinuteOfDay: schedule.endMinuteOfDay
        ) {
            let interval = RegisteredInterval(
                activityName: expansion.activityName,
                scheduleID: schedule.id,
                selectionData: selectionData,
                weekday: expansion.weekday,
                startMinuteOfDay: schedule.startMinuteOfDay,
                endMinuteOfDay: schedule.endMinuteOfDay
            )
            try service.registerSchedule(interval)
            registry[expansion.activityName] = interval
        }
        SharedState.scheduleRegistry = registry
    }

    /// Blocklist edits propagate here (SE-9). A registry-data swap, NOT a
    /// DeviceActivity re-registration: stopMonitoring a mid-window interval
    /// cancels its pending intervalDidEnd — the janitor that clears shields —
    /// violating trust invariant #1. The extension reads the registry at
    /// intervalDidStart, so swapping bytes is enough for every future fire;
    /// intervals already inside their window (and a running manual session)
    /// get re-shielded in-app right now.
    func refreshSchedules(blockList: BlockList) {
        // Empty pick: callers disable schedules through unregister; the registry
        // can't carry nil, and a running session's own end timer clears it.
        guard let selectionData = blockList.selectionData else { return }

        var registry = SharedState.scheduleRegistry
        for (name, var interval) in registry {
            interval.selectionData = selectionData
            registry[name] = interval
        }
        SharedState.scheduleRegistry = registry

        let now = ClockProvider.now()
        for interval in registry.values where ScheduleMath.isActive(
            weekdays: [interval.weekday],
            startMinuteOfDay: interval.startMinuteOfDay,
            endMinuteOfDay: interval.endMinuteOfDay,
            at: now
        ) {
            service.applyShields(selectionData: selectionData, activityName: interval.activityName)
        }

        if let snapshot = activeSnapshot {
            service.applyShields(selectionData: selectionData, activityName: snapshot.activityName)
        }
    }

    func unregister(schedule: FocusSchedule) {
        var registry = SharedState.scheduleRegistry
        let names = registry.values.filter { $0.scheduleID == schedule.id }.map(\.activityName)
        service.unregisterSchedules(activityNames: names)
        for name in names {
            service.clearShields(activityName: name)
            registry[name] = nil
        }
        SharedState.scheduleRegistry = registry
    }

    /// Settings → reset: stop everything, clear every store, wipe shared state.
    func resetAll() {
        let names = SharedState.activeSessions.map(\.activityName) + Array(SharedState.scheduleRegistry.keys)
        service.stopActivities(names)
        for name in names {
            service.clearShields(activityName: name)
        }
        SharedState.reset()
        activeSnapshot = nil
    }
}
