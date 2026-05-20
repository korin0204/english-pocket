# Foundational Learnings

This document records implementation knowledge discovered while stabilizing the core macOS capture and translation loop. These points affect product architecture and should be preserved across future refactors.

## Capture Is Multi-Path

macOS Services are the stable default path, but they are not universal.

- Browser text and Preview PDFs often work well with Services.
- App-rendered text surfaces such as Codex, ChatGPT, VS Code, and custom editors may not expose selected text through Services consistently.
- App keybindings can consume shortcuts before Services sees them.
- `Ctrl+Option+C` worked well as a Services shortcut in some apps, but using the same binding for app-level capture caused conflicts and inconsistent behavior.

Current policy:

- Keep Services as the default capture path.
- Keep advanced global capture opt-in.
- Use a separate shortcut for advanced capture: `Ctrl+Option+Shift+C`.
- Advanced capture should try Accessibility selected text first, then clipboard fallback.
- Clipboard fallback must preserve and restore the user's pasteboard when possible.
- Capture code must debounce duplicate captures because Services and advanced capture can both fire around the same user action.

## Global Capture Has Real Limits

Accessibility and clipboard fallback improve coverage but cannot make capture truly universal.

- Secure fields and protected/DRM surfaces may expose nothing.
- Some apps do not provide useful focused Accessibility elements.
- Synthetic copy can fail or trigger app-specific behavior.
- Advanced capture requires clear Settings UI and permission state.

Do not make advanced capture the default unless a future helper architecture proves it is stable across real apps.

## Translation Needs Request-Scoped State

On macOS 15-25, Apple Translation must run through SwiftUI `translationTask`. It is sensitive to SwiftUI view lifecycle.

Observed failure modes:

- A hidden or 0-size shared resolver can miss initial pending work when the popover appears after capture.
- Reusing one resolver for repeated requests can fail to retrigger translation.
- Updating only request IDs is not enough; `translationTask` is driven by `TranslationSession.Configuration`.
- A single mutable pending request can be overwritten when words are captured in quick succession.

Current stable pattern:

- Save the lexeme first.
- Queue UI translation requests.
- Process one translation at a time.
- Render one request-scoped `TranslationTaskView` per active request.
- Force a new SwiftUI task identity with `.id(request.id)`.
- Show the active translation task and queue count in the UI.
- Provide cancel-current and cancel-all controls.
- Log queued, started, applied, failed, and cancelled translations.

## From/To Languages Must Be Explicit

Implicit language detection is not reliable enough for this workflow.

- Settings should include source and target language.
- Default source is English.
- Default target is Japanese.
- Apple Translation UI should receive explicit source and target languages.
- macOS 26 direct translation must keep availability-gated APIs behind `#available(macOS 26.0, *)`.

## Menu Bar Apps Need Full Lifecycle Controls

Because English Pocket is resident in the menu bar:

- It must always provide a visible quit path.
- It must prevent duplicate running instances.
- Local development should stop old processes before launching a rebuilt app, because macOS Services can deliver requests to an older process.
- Settings should expose meaningful operational controls, not only debug values.

## Add/Delete Symmetry

Every path that creates user data should be paired with a deletion path in the same milestone.

Implemented expectations:

- Add lexeme manually.
- Add lexeme from Services.
- Add lexeme from advanced capture.
- Delete one lexeme from Library and Review.
- Clear all lexemes from Settings with confirmation.
- Destructive actions require confirmation.

## Diagnostics Are Product Infrastructure

This app depends on OS integration points that can fail differently per app and per permission state.

Keep diagnostics for:

- Services invocation and pasteboard types.
- Advanced hotkey registration.
- Accessibility selected text failures.
- Clipboard fallback failures.
- Translation queue and task lifecycle.

Current log path:

```text
~/Library/Application Support/EnglishPocket/EnglishPocket.log
```

