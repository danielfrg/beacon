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

Launch the app pointed at a server without typing the URL (simulator):

```sh
xcrun simctl launch booted com.example.Beacon -serverURL http://127.0.0.1:5000
```

## UI tests

End-to-end flows run against the mock server (start it first):

```sh
python3 tools/mock-frigate/server.py &
xcodebuild test -project Beacon.xcodeproj -scheme BeaconUI \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Live view

Full-screen live view uses WebRTC, negotiated over Frigate's signaling WebSocket on the normal Frigate port
(`/live/webrtc/api/ws`). Video flows over go2rtc's WebRTC port (8555 by default), so the server must advertise
a candidate address your phone can reach (`go2rtc.webrtc.candidates`). If WebRTC can't connect, the view
falls back to refreshing snapshots and shows why.

Known limitations (MVP): no authentication, plain HTTP on a local network only, no audio, no recordings,
and the iOS WebRTC build reliably decodes H.264 only (H.265 cameras may fall back to snapshots).
The first time you connect, iOS asks for local network access; allow it.
