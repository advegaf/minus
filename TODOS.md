# minus — deferred scope

## What still stands between here and a release (as of 1.13.0)

Ranked by what actually blocks, not by effort.

1. **The identity launcher is a private API.** `LSApplicationWorkspace
   .openApplicationWithBundleID:` is what makes any-app launching work at all,
   and it is an automatic App Store rejection. This build is personal, by
   decision, so it ships as is — but "release" here means *onto your phone*,
   not into the store. Distributing publicly means deleting the identity route
   and living with schemes plus Shortcuts, which is a materially worse app.
   `PrivateAppLauncher.isEnabled` (DEBUG row in About) is the switch.
2. **The widget's identity launch is still unproven.** The app process
   launches by identity on hardware (verified: Telegram killed at pid 3665,
   relaunched at 3754). Whether an app EXTENSION gets the same privilege has
   never been tested, because it needs one human tap on a home-screen widget
   cell. If it is refused, those cells fall back to the Link bounce through
   minus, which still lands every app — one visible blink instead of none.
3. **Family Controls distribution entitlement** — required before TestFlight
   or the App Store, whatever happens with (1). File it when shipping becomes
   real.
4. **iOS 27 simulator stalls any test that types.** A beta-runtime keyboard
   problem, not an app one; the 26.4 simulator covers those paths and the full
   suite is green there. Recorded rather than papered over.
5. **The Oura fix needs one tap to confirm.** Threading the identity through
   Home, the trampoline and the snapshot is unit-tested, but the acceptance
   test is a human tapping an added app on hardware and NOT seeing "could not
   open shortcut".
6. **Two CSV rows sit at Fixed–retest** (L-4 link verification, and the
   pre-1.10 launch rows) pending a device walk. Seven more are Needs device by
   nature: shields, schedules and the report extension cannot run on a
   simulator.

Worth improving, in order of what a user would feel:

- **Added apps cannot be renamed**, only removed and re-added.
- **The launcher has no reordering.** Card membership is toggle-only, so the
  order is the catalog's, not yours. At 268 rows this is felt more than it was
  at 60.
- **Nine apps from the library were left out** as too ambiguous to resolve
  safely: Genie, Nutri Coach, Shopper, Workouts, Playground (Apple's Image
  Playground shipped instead), Bites' near-namesakes, and Superpower and Zelle,
  which have no launchable identity at all. Each is still one search away.
- **The catalog needs re-verifying when it changes.** `python3
  scripts/build_catalog.py` prints every resolution; reading that log is what
  catches a valid id pointing at the wrong app.
- **iCloud sync, Lock Screen widgets, a per-card default for new widgets** —
  real features, none of them blocking.

## v2 candidates, in rough priority order:

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
