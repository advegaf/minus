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

## v1.1 additions (widgets + counts + re-pick)

| # | Story | Do | Expect |
|---|---|---|---|
| 12 | W-1/W-3 | Long-press home screen → add minus's large launcher + small focus widgets | Obsidian ground, the chosen typeface, essentials as text cells |
| 13 | TY-2 | Settings → typeface → pick a face, background the app, check the widgets | Widgets and the Screen Time report both redraw in the chosen face. Force-quit the app and re-add a widget: it still reads the face from the app group |
| 14 | AW-9 | Awareness, cold | The stats rise in a stagger; the screen-time panel CROSSFADES over "no numbers yet today." rather than hard-cutting (allow 1-3 s). With Reduce Motion on, both degrade to a plain 0.2 s ease |
| 13 | W-2 | Tap a launcher cell with minus force-quit (cold), then again warm | Both times: minus flashes, target app lands foreground |
| 14 | W-4 | Start a 15-min session, force-quit minus, watch the small widget at the end time | Widget flips from "FOCUSED until…" to idle on its own |
| 15 | ON-6/SE-3/SE-9 | Settings → blocked apps → re-pick: select one full category | Summary counts member apps ("N apps · 1 category"); with a schedule mid-window, About → monitor log confirms the re-shield |

## v1.6 additions (cards, config widget, any-app essentials)

| # | Story | Do | Expect |
|---|---|---|---|
| 16 | CA-2 | Update over a v1.5 install (widget already placed) | Placed LARGE launcher survives the update and renders identically (defaults); a placed MEDIUM widget goes blank/ghost - remove and re-add as large (two sizes now) |
| 17 | CA-5 | Long-press the launcher widget → Edit Widget | Three controls: Card / Text size (small-medium-large) / Placement (left-centered); changes render immediately |
| 18 | CA-1/CA-5 | Make a second card in Settings → cards; point a second widget at it | Two widgets, two different app sets, independent type sizes |
| 19 | CA-4 | Settings → cards → a card → "+ an app we don't list": type any installed app's name; create the matching one-action shortcut (minus-{slug}) | Widget/Home tap opens that app via Shortcuts with no minus flash |
| 20 | CA-7 | About → scheme lab (DEBUG): tap the low/medium-confidence rows | Note which land on the app's main screen; wrong ones just no-op (report back for catalog promotion) |
| 21 | W-1 | Add the full-page launcher (very large, iOS 27) | Full home page of sculptural names; Edit Widget size/placement apply; 6-7-app cards tighten + step down type, never clip |

## v1.7 additions (goal visibility, card swipe, calmer motion)

| # | Story | Do | Expect |
|---|---|---|---|
| 22 | V-1 | Settings -> intention -> VISIBILITY -> hidden | Goal disappears from Home AND from every widget footer (background the app once so the snapshot republishes); settings row reads "hidden"; text still there when you switch back to shown |
| 23 | CA-8 | On Home, swipe left/right across the launcher area (needs 2+ cards) | Pages between cards; card names above act as tabs (bone = current); nothing shifts vertically as you swipe; cold launch returns to card one |
| 24 | V-3 | Tap around: rows, CTAs, focus start/stop, screen pushes | Motion settles instead of snapping; press feedback still immediate; nothing bounces |
| 25 | CA-2 | Update over the v1.6 build | Store opens without a crash (no migration stage - additive property, implicit lightweight); cards and goal text survive |

## v1.9 additions (universal links, widget bounce, motion)

| # | Story | Do | Expect |
|---|---|---|---|
| 26 | L-1 | Tap spotify, discord, instagram, youtube in the HOME SCREEN WIDGET | Each opens the app directly, no minus flash. If one opens Safari instead, note it: that link needs promoting in the lab |
| 27 | L-2 | Tap phone or a custom entry in the widget | Black blink through minus, then your shortcut runs and the app opens |
| 28 | L-3 | Settings > about > link lab: tap every row | Note app vs Safari for each. Report back and I promote the winners |
| 29 | M-1 | Tap the focus widget with minus closed | minus opens straight ON the focus screen: no Home flash, no slide, nothing animating in as something animates out |
| 30 | UX-4 | Make an empty card (+ on Home), then look at Home | "nothing here yet. choose essentials" with essentials bold white; tapping it opens THAT card's editor |
| 31 | M-2 | Move around the app generally | Motion should feel of a piece: entrances settle, exits are quicker, pushes are the system's and match the edge-swipe |

Debugging: Settings → about → monitor log (DEBUG builds) is the app-group ring buffer
the extension writes. `intervalDidEnd` can lag by up to ~2 minutes — that's Apple's
scheduler, not a bug; the foreground sweep covers worse.
