# minus — on-device Screen Time checklist

The simulator can never shield apps. Every `Needs device` row in
`QA/feature-stories.csv` gets verified here, once, on real hardware.

## Setup (one-time)

1. iPhone on the same Apple ID team as `Config/Secrets.xcconfig`
   (`DEVELOPMENT_TEAM`), Developer Mode on.
2. Build + install:
   ```bash
   xcodegen generate
   xcodebuild -project Minus.xcodeproj -scheme Minus \
     -destination "platform=iOS,name=<your iPhone>" \
     -allowProvisioningUpdates -derivedDataPath build-device build
   xcrun devicectl device install app --device <udid> \
     build/Build/Products/Debug-iphoneos/Minus.app
   ```
3. First launch → complete onboarding with the REAL FamilyActivityPicker.

## The walk (order matters)

| # | Story | Do | Expect |
|---|---|---|---|
| 1 | ON-4 | Allow Screen Time at the permission step | System consent sheet; approved advances |
| 2 | ON-5 | Pick 2–3 real apps + 1 category in the picker | Summary line shows the counts |
| 3 | FO-1d | Start a 15-minute session; open a blocked app | Apple's shield covers it immediately |
| 4 | FO-1d | Open an essential app | Opens normally (never shielded) |
| 5 | FO-6 | Start a session, force-quit minus, wait out the interval | Shield lifts ON TIME with the app dead; relaunch → session shows completed (reconciled from the ledger); About → monitor log shows `didEnd` |
| 6 | FO-7 | Start a session, end early through the strictness gate | Shield lifts instantly |
| 7 | FO-9d | Create a schedule starting ~20 min out; leave the app closed | Shield appears at start (monitor log `didStart`), lifts at end |
| 8 | AW-3 | Open Awareness | DeviceActivityReport renders real screen time + pickups (allow 1–3 s skeleton) |
| 9 | SE-4 | Settings → re-pick blocked apps | Picker reopens with prior selection |
| 10 | SE-6 | Settings → Screen Time → revoke in system Settings → return | Home shows the revoked band; Focus shows denied state |
| 11 | SE-7 | Reset everything mid-session | Shields lift, schedules gone, back to onboarding |

Debugging: Settings → about → monitor log (DEBUG builds) is the app-group ring buffer
the extension writes. `intervalDidEnd` can lag by up to ~2 minutes — that's Apple's
scheduler, not a bug; the foreground sweep covers worse.
