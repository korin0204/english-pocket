# Architecture

English Pocket starts as a macOS-native product with shared core logic.

## Packages

- `EnglishPocketCore`: data model, normalization, local storage, translation boundary, CSV export, and review scheduling.
- `EnglishPocketMac`: AppKit status item, macOS Services receiver, SwiftUI popover, settings, capture, library, and review views.

## Capture Flow

English Pocket has two capture paths.

### Services Capture

1. The user selects text in another macOS app.
2. The macOS Service `Save to English Pocket` receives text through `NSPasteboard`.
3. `ServiceProvider` creates a `CaptureRequest`.
4. `AppModel` asks `HybridTranslationService` for a translation.
5. `LexemeStore` normalizes text, merges duplicates, records the occurrence, and persists the lexeme.
6. The menu bar popover updates Inbox, Library, and Review state.

### Global Shortcut Capture

1. When enabled in Settings, `GlobalHotKeyController` registers `Ctrl+Option+Shift+C` with Carbon.
2. `SelectionCaptureReader` first tries the focused app's Accessibility selected text.
3. If Accessibility cannot provide text, it sends a temporary Cmd+C, reads `NSPasteboard.general`, and restores the prior pasteboard items.
4. `AppModel` debounces duplicate captures so Services and the global shortcut do not double-count the same selection.
5. The popover opens and displays the fastest available translation result.

The Mac app enforces a single running instance. During local development, duplicate processes can cause macOS Services to deliver selected text to an older app binary.

## Storage

The prototype uses a JSON store at:

```text
~/Library/Application Support/EnglishPocket/lexemes.json
```

This keeps Milestone 0 lightweight. Milestone 2 should replace or migrate this to Core Data with CloudKit.

## Translation

`HybridTranslationService` is the stable boundary.

Provider order:

1. macOS 26+: Apple Translation direct provider when the required language pair is installed and available.
2. macOS 15-25: SwiftUI `translationTask` inside the app surface.
3. Local fallback dictionary for prototype behavior.
4. Future backend LLM/cloud provider for enrichment and fallback.

On macOS 15-25, SwiftUI `translationTask` should be treated as UI-lifecycle-sensitive. The stable pattern is one active queued request at a time, rendered through a request-scoped task view with `.id(request.id)`, plus visible progress and cancellation controls. Do not collapse this back into one hidden shared resolver without re-testing repeated translations.

## Review Scheduling

The current scheduler is intentionally simple and local. It supports the four expected grades:

- Again
- Hard
- Good
- Easy

Milestone 5 should replace this with a fuller FSRS-style scheduler while preserving the grade interface.
