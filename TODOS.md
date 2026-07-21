# minus — deferred scope

v2 candidates, in rough priority order:

1. **Home-screen widget** (deferred from v1 by decision D7) — small/medium WidgetKit
   widget: intention line + current focus state in the obsidian/bone language. Needs an
   App Group snapshot (pattern already exists in `SharedState`) and a `MinusWidget`
   target.
2. **Custom shield appearance** — `ShieldConfigurationExtension` target so Apple's
   shield sheet carries the minus voice (system layout only: icon/title/subtitle/
   buttons — no custom fonts, no prism).
3. **Cross-midnight schedules** — v1 validates same-day windows only; midnight-crossing
   needs paired intervals across two weekdays.
4. **Intention history** — `UserConfig` holds a single current intention; a log of past
   intentions with dates could feed a reflective view.
5. **PP Neue Montreal** — buy the app license and swap the two font names in
   `Typography.swift` (`MFont.regular/bold`) + `fetch_fonts.sh` + `UIAppFonts`.
6. **Family Controls distribution entitlement** — required before TestFlight/App Store;
   file the request with Apple when shipping becomes real.
