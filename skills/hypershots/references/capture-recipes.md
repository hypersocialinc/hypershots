# Capture recipes

Field-proven simulator recipes for taking the app captures that go in `<ws>/assets/`. **Scope:** bespoke marketing frames only — bulk/configured capture across devices and locales stays fastlane snapshot's job (see SKILL.md "when not").

Get the simulator UDID from `xcrun simctl list devices booted`.

## Marketing-clean status bar

Override the status bar before the first capture — full bars, full battery, Apple's canonical 9:41, no carrier name:

```bash
xcrun simctl status_bar <udid> override --time "9:41" \
  --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularBars 4 --operatorName ""
```

Clear it when the whole session is done:

```bash
xcrun simctl status_bar <udid> clear
```

**Gotcha:** an override cleared mid-session (a sim reboot, a stray `clear`, another tool resetting the device) makes later captures silently disagree with earlier ones — mixed times and battery states across one set read as sloppiness. Set the override once at the start, clear it at the very end, and verify **9:41 in every capture you Read** before dropping it into `assets/`.

## Appearance (light/dark)

```bash
xcrun simctl ui <udid> appearance light   # or: dark
```

The simulator boots in whatever appearance was last used — never assume. Match the brand: a light-paper theme with dark-mode captures (or vice versa) fights itself inside the frame.

## Mid-gesture captures (held drag, swipe stamps)

There is no hold-a-drag API — HID touch-move fails on the FBSimulator backend. The recipe is burst capture: a background screenshot loop plus a foreground gesture slowed enough for the loop to catch the mid-gesture frame.

```bash
# background: ~40 frames while the gesture runs
mkdir -p burst && for i in $(seq -w 1 40); do
  xcrun simctl io <udid> screenshot "burst/frame-$i.png"
done &
# foreground: the SLOW gesture (e.g. an 8s scroll preset), then wait for the loop
```

Montage the burst and pick the best held-drag frame:

```bash
magick montage burst/frame-*.png -tile 8x -geometry +2+2 burst-sheet.png
```

**Etiquette:** gestures COMMIT at release. When driving real user data, undo every action you cause — a burst-captured swipe still archives the card. And swipe direction maps to semantics: swipe the direction whose stamp/affordance you want in the frame.

## Camera/AR apps — capture on a real device

The simulator's camera is a black feed, so any app whose core surface is the camera (workout form tracking, AR, scanning) cannot be captured with simctl — and App Review 2.3.3 means the store set needs REAL camera content in the device, not an invented screen (see gotchas.md, "Invented app UI in the device").

- **Stills:** hardware screenshot on the device (Side + Volume Up), AirDrop to the Mac. Fastest path, real status bar included.
- **Mid-action frames** (the money shots for camera apps): cable the iPhone to the Mac → QuickTime Player → File → New Movie Recording → pick the iPhone as the camera source. This mirrors the device screen (QuickTime even fakes a clean 9:41 status bar in this mode). Record the whole workout/scan, then pull the exact frame:

```bash
ffmpeg -i recording.mov -vf "select='eq(n,412)'" -vframes 1 frame.png   # or:
magick recording.mov[412] frame.png
```

- **Status bar caveat:** `simctl status_bar` doesn't exist for real devices. QuickTime's mirror mode gives you the clean bar for free; hardware screenshots keep the real one — consistent real bars across a set beat a mix.
- Drop the chosen frames in `<ws>/assets/` and use them as ordinary `.shot` captures. Until real captures exist, any hand-built stand-in screen must carry `data-mockup="screen"` (create.md, mockup policy).

## Automated capture at scale (Swift-native projects)

These recipes cover bespoke marketing frames. For capturing MANY screens across
device×locale×appearance matrices in a Swift/Xcode project, a dedicated capture
tool beats hand-driving the simulator:

- **StoreScreens** (open-source, `brew`): generates XCUITests from your Swift
  source and runs them across simulators in parallel, per locale and light/dark —
  https://github.com/ciscoriordan/storescreens-cli. Use its `capture` output as
  the raw screens, then author HyperShots panels around them (its `render`
  templates and HyperShots panels are alternatives — pick one, don't stack).
- **fastlane snapshot**: the classic UI-test-driven capture lane; pairs naturally
  with the fastlane-deliver setup in `fastlane-deliver.md`.

React Native / Flutter / Expo projects: drive the simulator with your usual
tooling (Maestro, Detox, or by hand with the recipes above) — capture is
stack-specific; the panels aren't.
