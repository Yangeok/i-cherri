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
- `make ios-run`: build, install, and launch on a connected iPhone
- `make ios-dev`: build, launch, then attach iOS console output

---

## Current Flow

1. Launch the macOS receiver app.
2. Launch the iPhone app and grant Photos and Local Network permissions.
3. Pair the iPhone with the Mac receiver.
4. Start backup from iPhone.
5. Inspect active sessions and backup history from the macOS dashboard.

---

## Security

- Use only on trusted local networks.
- Do not expose the receiver to the public internet.
- Do not reuse pairing data across untrusted machines.

---

## Status

The repository has been migrated away from the older Go server and Shortcut-based backup flow.
Current development targets the Swift-native iPhone and macOS apps only.
