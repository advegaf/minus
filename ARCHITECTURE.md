# minus — architecture

Five targets, one trust invariant: **shields always come down.**

## Targets

| Target | Kind | Purpose |
|---|---|---|
| `Minus` | app | SwiftUI app, all UI, session orchestration |
| `MinusMonitor` | DeviceActivityMonitor extension (NSExtension) | applies schedule shields at `intervalDidStart`, clears shields at `intervalDidEnd` — even when the app is dead |
| `MinusReport` | DeviceActivityReport extension (ExtensionKit) | renders real screen-time/pickups inside Apple's sandbox; the host can never read the numbers |
| `MinusTests` / `MinusUITests` | tests | pure engines in milliseconds; story flows via accessibility ids |

## Session lifecycle (the core)

1. **Start (in-app):** `SessionCoordinator.start` → insert `FocusSession` row → apply
   shields immediately via named `ManagedSettingsStore(named: activityName)` → register a
   one-shot DeviceActivity interval as the end-timer → snapshot to the app group.
   Shields are instant; the extension is only the janitor.
2. **End (app alive or dead):** `MonitorExtension.intervalDidEnd` clears the named store
   and appends to the app-group pending-events ledger. On next foreground,
   `reconcile()` drains the ledger into SwiftData and **sweeps** any snapshot past its
   planned end (missed-callback belt-and-braces).
3. **Schedules:** weekday expansion → one `DeviceActivityName` per (schedule, weekday)
   (`ScheduleMath`, pure). The extension applies shields from the app-group
   `scheduleRegistry` at `intervalDidStart`. Constraints enforced in UI: ≥15-minute
   windows (API minimum), ~19-activity budget, same-day windows only (a window may
   not cross midnight, and an end past minute 1439 is rejected outright — it would
   expand to hour 24). An all-day window (00:00 to 23:59) registers with
   `second = 59`, so consecutive days meet without leaving the night open.
4. **Honesty:** deleting the app releases all shields. Strict mode is friction, not a
   jail, and the copy says so.

## Isolation & persistence

- `SharedState.swift` is compiled into **both** the app and the monitor extension —
  the entire contract (active snapshots, schedule registry, pending-event ledger,
  monitor ring-buffer log) is small JSON in the app group. The extension never opens
  SwiftData (single-digit-MB jetsam ceiling).
- SwiftData (`MinusSchemaV1`): CloudKit-legal rules (defaulted/optional properties, no
  `#Unique`, fetch-before-insert singletons). Stats derive live from `FocusSession`
  rows — no materialized stat tables.
- `ScreenTimeService` protocol: `LiveScreenTimeService` (FamilyControls) on device,
  `MockScreenTimeService` on simulator/`-UITestMode` — 100 % of screens drive in the
  simulator; the mock simulates the full lifecycle including the end-of-interval ledger
  write.

## Swift 6 strict-concurrency findings (iOS 26.4 SDK)

- `AppExtensionScene` (ExtensionKit parent of `DeviceActivityReportScene`) is
  `@MainActor`, but `DeviceActivityReportScene`'s own requirements and
  `DeviceActivityReportExtension.body` are **nonisolated**. Working shape: scene struct
  holds no stored state, every witness explicitly `nonisolated`, `@ViewBuilder`
  transform suppressed with an explicit `return` (SE-0289), and the report view gets a
  `nonisolated init`.
- All Screen Time API touches confined to `@MainActor` (`SessionCoordinator`,
  `LiveScreenTimeService`); the monitor extension creates stores locally per callback.

## Design system

`Minus/DesignSystem/` — Vivid+Co, dark-only. One typeface at a time (400; 700 only at
28pt), fixed sizes (no Dynamic Type), hierarchy from scale. Zero shadows. Prism RGB
lives `fileprivate` in `PrismArtifact.swift`. `DesignGuardTests` scans the source and
fails the build-loop on: any `.shadow(`, prism hexes outside `Prism/`, `.font(.system`,
raw `Color(` constructors outside the design system, and any font name off the approved
allowlist.

Which typeface is the user's choice, from five approved faces. `Typeface.swift` is a
third contract file (alongside `SharedState.swift` and `LauncherSnapshot.swift`),
compiled into the app, the widget, and the report: it owns every PostScript name and
mirrors the pick into the app group, since neither extension can read SwiftData.
`.mnType` is a modifier reading `\.mnTypeface` from the environment, so a pick
re-renders text and nothing else. Time displays render per-digit in fixed-width slots
(none of the faces have `tnum`), and `DigitMetrics` measures those slots **per face** —
a slot measured against one face and drawn in another is how a 96pt monument ends up
mis-tracked.

## Determinism harness (DEBUG)

`-UITestMode` (in-memory store, mock service, shared-state reset) ·
`MINUS_STATE=fresh|onboarded|active|schedules|noblock|noessentials|denied`
(DemoSeed) · `MINUS_AUTH=denied` (auth failure with any state) ·
`MINUS_STRICTNESS=normal|friction|strict` · `MINUS_BLOCK=stale` (undecodable
selection — the restore scenario) · `MINUS_FREEZE_TIME=HH:mm` (pins
`ClockProvider`) · `MINUS_SCREEN=gallery|focus|awareness|settings|schedules|
settings-{blocked|permission|strictness|about}` (deep-jump) ·
`MINUS_ONBOARDING_STEP=<step>` (onboarding jump) ·
`MINUS_GALLERY_SCROLL=<section>` (gallery anchor).
