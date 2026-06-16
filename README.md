<p align="center">
  <img src="assets/logo.png" width="300" />
</p>

# i-cherri

<p align="center">
  <b>English</b> |
  <a href="README.ko.md">한국어</a>
</p>

**i-cherri** is a Swift-native local network photo backup app pair for iPhone and Mac.
The iPhone app scans the photo library, discovers a Mac receiver over Bonjour, and uploads media in resumable chunks to the macOS app.

---

## Architecture

- `apps/ios/`: iPhone backup client built with SwiftUI
- `apps/mac/`: macOS receiver app built with SwiftUI
- `packages/ICherriProtocol`: shared DTOs and API contracts
- `packages/ICherriCore`: deduplication, hashing, and backup core logic
- `packages/ICherriDesignSystem`: shared UI components

---

## Requirements

- Xcode 16+
- macOS with local network access
- iPhone running the iOS app on the same LAN
- Make

---

## Development

```bash
make mac-app
make ios-app
```

Common workflows:

- `make mac-run`: build and launch the macOS receiver app
- `make mac-dev`: build, launch, then stream macOS logs
- `make mac-dmg-notarized-arm64`: build, notarize, staple, and verify an Apple Silicon DMG
- `make mac-dmg-notarized-x86_64`: build, notarize, staple, and verify an Intel DMG
- `make mac-dmg-notarized-assets`: build notarized DMGs for both macOS architectures
- `make ios-run`: build, install, and launch on a connected iPhone
- `make ios-dev`: build, launch, then attach iOS console output

Notarized macOS release targets require:

- `MAC_RELEASE_SIGN_IDENTITY`: your `Developer ID Application: ...` certificate name
- One notarization auth mode:
  - `MAC_NOTARYTOOL_PROFILE`: keychain profile created with `xcrun notarytool store-credentials`
  - or `MAC_NOTARY_APPLE_ID`, `MAC_NOTARY_TEAM_ID`, `MAC_NOTARY_APP_PASSWORD`

Example:

```bash
MAC_RELEASE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
MAC_NOTARYTOOL_PROFILE="icherri-notary" \
make mac-dmg-notarized-arm64
```

Release cleanup:

- `make dist-reset-release`: remove and recreate only `dist/`
- `make clean`: remove both `.build/` and `dist/`

---

## Current Flow

1. Launch the macOS receiver app.
2. Launch the iPhone app and grant Photos and Local Network permissions.
3. Pair the iPhone with the Mac receiver.
4. Start backup from iPhone.
5. Inspect active sessions and backup history from the macOS dashboard.

## Automatic Backup Operations

- Turn on `Automatic Backup` in the iPhone backup dashboard.
- Automatic backup prepares runs only when battery is at least `20%` and Wi-Fi is available.
- The iPhone keeps a local run store with staged upload usage, receiver selection, recent results, and the next scheduled evaluation time.
- The macOS receiver keeps resumable upload session context and treats replayed chunks idempotently.
- If the receiver disappears or the iPhone becomes too warm, the run pauses and surfaces the reason in the iPhone UI.
- Staged upload files are capped at `2 GB` total per automatic run store snapshot.

Recommended targeted verification:

```bash
xcodebuild test -project apps/ios/iCherri-ios.xcodeproj -scheme iCherri-ios -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY='' -only-testing:iCherri-iosTests/AutoBackupEngineTests -only-testing:iCherri-iosTests/AutoBackupJobStoreTests -only-testing:iCherri-iosTests/AutoBackupStatusViewModelTests -only-testing:iCherri-iosTests/ResumableUploadManagerTests

xcodebuild test -project apps/mac/iCherri-Mac.xcodeproj -scheme iCherri-Mac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY='' -only-testing:iCherri-MacTests/DatabaseManagerBackupRunTests -only-testing:iCherri-MacTests/AutoBackupReceiverContractTests
```

---

## Security

- Use only on trusted local networks.
- Do not expose the receiver to the public internet.
- Do not reuse pairing data across untrusted machines.

---

## Status

The repository has been migrated away from the older Go server and Shortcut-based backup flow.
Current development targets the Swift-native iPhone and macOS apps only.
