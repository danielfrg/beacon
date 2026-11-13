# Agent instructions

Beacon is an iOS app for Frigate.

It should connect directly to a frigate installation.

You can find the frigate source code in ~/code/frigate in case you need to
take a look at how things work.

## Build and run

- The Xcode project is generated from `project.yml` with XcodeGen (`xcodegen generate`).
  Never hand-edit `Beacon.xcodeproj`; it is git-ignored.
- Build and run on the simulator with `xcodebuild` and `xcrun simctl` (see README).

## Design

Objectives:

- Feel like a native iOS app: system navigation, controls, typography, SF Symbols,
  standard gestures. No custom chrome for its own sake.
- Functional first, but it should still look great: clean, calm and well spaced.
- Dark-first. Content (camera imagery) is the hero; the UI stays out of the way.
- Camera list: a vertical stack of large rounded cards, each a live snapshot with
  the camera name and a small status indicator overlaid.
- Live view: full-screen, black background, minimal translucent overlay controls
  (close, mute, info) that fade away; image centered at its aspect ratio.
- Settings and management screens use standard grouped lists; reordering and
  show/hide use the native edit-mode patterns.
- Prefer glanceable: a user should see all cameras at once or reach one camera in one tap.
- Be gentle on battery and bandwidth: no grid of simultaneous video decoders.
- Mostly read-only; any action that changes the server is explicit and clearly labelled.

Never include real hostnames, domains or IPs in the repo; use example.com and
RFC 5737 addresses in docs and tests.
