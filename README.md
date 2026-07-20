# minus

A digital-minimalism iOS app. An obsidian void with a giant clock, your
intention, the few apps you actually need — and real app blocking via Apple's
Screen Time API when you choose to focus.

Design language: dark-only, one typeface at weight 400, hierarchy from scale,
zero shadows, and a single chromatic voice (the prism artifact).

## Build

```bash
./scripts/fetch_fonts.sh        # once after clone (General Sans, Fontshare)
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # fill in your team
xcodegen generate
xcodebuild -project Minus.xcodeproj -scheme Minus \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
```

The simulator always runs against `MockScreenTimeService` — real shields
(FamilyControls) require a physical device with dev signing.

## QA

`QA/feature-stories.csv` is the canonical feature/story matrix; evidence
screenshots live in `QA/evidence/` named `{ID}.png` (and `{ID}-fixed.png`
after a fix). See `docs/DEVICE-TESTING.md` for the on-device checklist.
