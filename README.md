# Cue

Cycle through several actions with one press of the iPhone Action button, and **see what
will run in the Dynamic Island** before it does.

*[한국어](README.ko.md) · Design notes: [DESIGN.md](DESIGN.md)*

<p align="center">
  <img src="docs/live-activity-cycling.png" width="440" alt="Lock Screen Live Activity — cycling with Flashlight selected">
</p>

<p align="center">
  <img src="docs/dynamic-island-compact.png" width="420" alt="Dynamic Island compact — selected action and time left">
  &nbsp;
  <img src="docs/live-activity-open.png" width="420" alt="Result with an Open button">
</p>

| | |
|---|---|
| Minimum | iOS 18.0 (`ControlWidget`) |
| Built with | Xcode 26.6 / iOS 26.5 SDK / **Swift 6 language mode** |
| Action button | iPhone 15 Pro or later — the Simulator has none |
| Languages | Korean · English |

## Why

The loudest complaint about the Action button is that it holds **one** action. Apps already
solve that — [Action Button Pro](https://apps.apple.com/app/id6471029467), ActionMate,
[the MultiButton shortcut](https://www.macstories.net/ios/introducing-multibutton-assign-two-shortcuts-to-the-same-action-button-press-on-iphone-15-pro/).

But **none of them give you feedback.** You cannot tell whether the press registered, what
ran, or what the next press will do. Checking Action Button Pro's App Store feature list
turned up no Live Activity, no Dynamic Island, no Control Center control (checked
2026-08-07) — its only surfaces are a Lock Screen widget and a Home Screen long-press.

That feedback layer is what Cue is.

## How it works

```
1st press   ( 🔦 Flashlight  0:02 )   ← Dynamic Island
2nd press   ( 📍 Mark        0:02 )   press again within 2s to move on
after 2s    ( ✓ ran )
```

Long-press the Dynamic Island and the whole set unfolds.

<p align="center">
  <img src="docs/dynamic-island-expanded.png" width="420" alt="Dynamic Island expanded — action strip with Cancel and Run">
</p>

Two ways to confirm:

| Path | What happens |
|---|---|
| **Leave it 2s** | The selected action runs on its own |
| **Double-tap an item** | That item runs immediately, no waiting |

The first tap moves the selection and reopens the window, so double-tapping any item runs
it without cycling there. Pressing after the window closes resets to the first item.

The Lock Screen card and the expanded Dynamic Island both show the whole set as a
**tappable strip** with **Cancel / Run**. A second Control Center control switches sets.

### Actions

Only what a background intent can actually do. Launching the system camera or flipping the
ringer have no third-party API, so they are not here.

| Kind | What it does |
|---|---|
| `torch` | Toggle the flashlight (`AVCaptureDevice`) |
| `mark` | Write the current time to the log |
| `stopwatch` | Start / stop a stopwatch |
| `openApp` | Puts an **Open button** on the result — the only thing that foregrounds the app |
| `openURL` | Same, for a link. **https only** — `OpenURLIntent` rejects custom schemes |

## Build

```bash
xcodebuild -project Cue.xcodeproj -scheme Cue -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

The Simulator has no Action button. Use the in-app **Press Cue** button, or the Shortcuts
app, to run the same intent.

For a device, set your **team** in Xcode and provision the App Group.

## Test

```bash
xcodebuild test -project Cue.xcodeproj -scheme Cue \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

| Layer | Count | Time | What |
|---|---|---|---|
| Unit + view render (Swift Testing) | 46 | ~3s | state machine 32 + views 14 |
| Integration smoke (XCUITest) | 5 | ~70s | wiring · localization, ko and en |

Zero warnings. Both layers passed twice in a row.

The view-render layer earns its place: temporarily removing a guard brought back a real
crash and the test died with `Fatal error: Range requires lowerBound <= upperBound`.
See [DESIGN.md](DESIGN.md#view-render-tests).

## What is verified, and what is not

Verified on an iPhone 17 Pro Simulator: cycling, the 2s auto-commit, **double-tap
confirming ahead of the auto-commit** (measured — a tap 0.668s after the first, done
0.546s later, before the 2.0s mark), Live Activity and Dynamic Island rendering, the Open
button actually foregrounding the app, English localization, Swift 6 with zero warnings.

**Not verified — a real device is required:**

- Pressing the actual Action button
- Whether `Task.sleep(2s)` survives the background on device — the weakest link in the
  design, and the Simulator is far more lenient
- The control showing up in the Control Center / Action button gallery
- Haptics and the flashlight — no engine, no torch in the Simulator

Full tables in [DESIGN.md](DESIGN.md#verification-status).

## Design notes

[DESIGN.md](DESIGN.md) carries the reasoning:

- How cycling and double-tap are told apart, and why `generation` is a monotonic
  invalidation token
- The commit wait — the weakest link
- Why opening the app is a separate intent
- Concurrency isolation under Swift 6
- Localization traps, UI-automation handles, the test layers
- Verification tables, known limits, what to do next

## Images

`app.png` and `dynamic-island-compact.png` are real Simulator screenshots. The other card
images are the production views (`CueActivityViews.swift`) drawn with `ImageRenderer` —
Lock Screen screenshots get iOS's Live Activity consent prompt over them, and a card lives
only a few seconds. Same views, same state, so they match the screen.
