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

## Reading the phone's installed apps (investigated, blocked)

iOS 26.4 added `FamilyControls.FamilyActivityData.installedApplications`, which
returns real `ManagedSettings.Application` values carrying `bundleIdentifier`
and `localizedDisplayName` — exactly the list minus wants, as public API.

It does not work for us today. On device (iOS 27) the call fails with:

    NSCocoaErrorDomain 4099: connection to com.apple.FamilyControlsAgent
    .data-access was invalidated: lookup error 159 - Sandbox restriction

That is an entitlement gate, not user consent: the SDK also adds
`AuthorizationStatus.approvedWithDataAccess`, implying a tier above plain
`.approved`. The plausible key was tried and rejected by provisioning:

    Entitlement com.apple.developer.family-controls.data-access not found and
    could not be included in profile.

So the list stays out of reach until Apple grants that tier (likely the same
request path as the Family Controls distribution entitlement). Until then,
"any app" is served by AppSearch: the user types a name, Apple's public
iTunes Search endpoint returns the bundle identifier, and minus launches by
identity from then on, offline.
