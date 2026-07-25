# App Store screenshots

Five frames at **1320 × 2868**, the App Store's 6.9" iPhone size, which is the
only size Apple now requires: every smaller class is scaled from it.

Captured on the **iOS 27 iPhone 17 Pro Max simulator** (Xcode 27 toolchain),
which renders at exactly that resolution, so `raw/` needs no cropping and the
composed frames inset a straight downscale.

| # | Frame | What it shows |
|---|---|---|
| 01 | widget | The real `systemLarge` launcher widget, placed on a live home screen |
| 02 | home | Clock, goal, launcher card |
| 03 | focus | An active session: the prism artifact and the countdown |
| 04 | cards | The card editor: search plus the categorised catalog |
| 05 | schedules | Recurring block windows |

`raw/` holds the untouched screenshots. The composed frames are built by

    python3 scripts/make_appstore_shots.py <raw-dir> QA/appstore

Headlines and sublines live at the top of that script; re-run it after editing.

## How frame 01 was staged

The widget is genuinely rendered by WidgetKit, not mocked: `MinusUITests
.WidgetHostUITests` drives SpringBoard to place it. The home screen was then
reduced to a single page holding only that widget, with every other app moved
to page 2, which is exactly the layout the in-app guide asks you to build.
SpringBoard refills page 0 from the App Library if the other apps have nowhere
to live, so they need a page of their own rather than deletion. Emptying the
dock (`buttonBar`) wedges SpringBoard; leave it alone.
