# Releasing to TestFlight

## One-time setup

1. Enroll in the Apple Developer Program (a free Apple ID can't upload).
2. Put your team and bundle ID in `Config/Local.xcconfig` (git-ignored):

   ```
   DEVELOPMENT_TEAM = YOURTEAMID
   PRODUCT_BUNDLE_IDENTIFIER = com.example.YourBeacon
   ```
3. In App Store Connect, create an app record with that bundle ID.
4. Sign in to Xcode (Settings → Accounts) so automatic signing can manage certificates.

## Each release

1. Bump `CURRENT_PROJECT_VERSION` in `project.yml` (must be unique per upload);
   change `MARKETING_VERSION` for a new user-facing version.
2. Run:

   ```sh
   scripts/release.sh              # archive + upload
   scripts/release.sh --no-upload  # archive + export an .ipa to build/export
   ```
3. Wait for processing, then enable the build under TestFlight.

## Notes

- `scripts/release.sh` generates `build/ExportOptions.plist` from your local team ID, so no
  account identifiers are committed.
- Export compliance: `ITSAppUsesNonExemptEncryption` is `NO` (WebRTC/TLS are standard encryption).
  Read the question once in App Store Connect to confirm it matches your situation.
- Internal testers (up to 100 App Store Connect users) need no review. External testers need
  Beta App Review and a privacy policy URL.
- TestFlight builds expire after 90 days.
