# English Pocket

English Pocket is a native-first language learning app prototype.

The current implementation targets the first roadmap milestones:

- macOS 15+ native menu bar app
- Swift / SwiftUI / AppKit implementation
- macOS Services capture for selected text
- Manual word and phrase capture
- Local-first storage
- Apple Translation-first provider with macOS 26 direct translation and macOS 15 in-UI translation
- Lightweight review queue
- CSV export

This repository intentionally avoids Electron, React Native, Flutter, and WebView-centered UI. Future iOS and Windows versions should be native to their platforms and share only durable boundaries such as data models, sync contracts, backend APIs, and learning algorithms.

## Build

```bash
swift test
swift build
./scripts/build_macos_app.sh
```

The packaged app is created at:

```text
.build/release/English Pocket.app
```

## Use The macOS Service

1. Build and run the app bundle.
2. Open System Settings.
3. Go to Keyboard > Keyboard Shortcuts > Services.
4. Enable `Save to English Pocket`.
5. Assign a shortcut.
6. Select text in another app and invoke the Service.

English Pocket can optionally register `Ctrl+Option+Shift+C` as an app-level advanced capture shortcut. This is off by default to avoid conflicts with app keybindings and user Services shortcuts. When enabled, it tries Accessibility selected text first, then a clipboard fallback.

For local development, quit any existing English Pocket process before launching a rebuilt app. macOS Services can keep sending requests to the older process if two copies are running.

The app stores data in:

```text
~/Library/Application Support/EnglishPocket/lexemes.json
```

Service diagnostics are written to:

```text
~/Library/Application Support/EnglishPocket/EnglishPocket.log
```

If a shortcut such as `Ctrl+Option+C` saves a control character instead of the selected word, the shortcut was handled while English Pocket's own text editor was focused. Select text in the source app first, or trigger the command from the source app's Services menu to verify the binding.

## Translation Behavior

- macOS 26 and newer use the direct Apple Translation provider when the language pair is installed.
- macOS 15 through 25 save first, then resolve Apple Translation inside the SwiftUI app surface with `translationTask`.
- The local dictionary fallback remains only for prototype behavior when direct translation is not available.
