# Beacon

A Frigate iOS app: a glanceable list of camera snapshots and a smooth full-screen live view (WebRTC).

## Develop

Requires Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) and an iOS simulator runtime.

```sh
xcodegen generate                      # regenerate Beacon.xcodeproj from project.yml
open Beacon.xcodeproj                  # or build from the CLI below
xcodebuild test -project Beacon.xcodeproj -scheme Beacon \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Mock Frigate server

No Frigate handy? Run a stand-in that serves `/api/config`, changing snapshots and toggle endpoints:

```sh
python3 tools/mock-frigate/server.py            # http://127.0.0.1:5000
python3 tools/mock-frigate/server.py --fail-toggles
```

Live (WebRTC) view needs a real Frigate server; against the mock it shows the snapshot fallback.
