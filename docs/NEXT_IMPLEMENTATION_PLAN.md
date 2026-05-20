# Next Implementation Plan: Selection Overlay Translation

## Goal

When the user captures selected text, English Pocket should show a compact translation overlay near the selected text instead of relying on the menu bar popover as the primary result surface.

The menu bar popover remains available for settings, library, review, task visibility, and fallback interactions.

## UX Requirements

- Show a small native overlay above the selected text when selection bounds are available.
- If exact selection bounds are unavailable, show the overlay near the selection context when possible, otherwise use a stable fallback near the mouse/menu bar.
- Keep the overlay concise: source text, translation, source/target language, saved state, and a dismiss affordance.
- Do not steal focus from the reading app unless the user explicitly interacts with the overlay.
- Do not dismiss the overlay by elapsed time. It should remain visible until the user dismisses it, presses Escape, or selects/clicks elsewhere.
- Dismiss the overlay when the user clicks/selects outside the overlay or presses Escape.
- Provide a fallback placement near the menu bar item or mouse location when selection bounds are unavailable.
- Never block saving. The word should be saved even if overlay positioning or translation fails.
- Preserve all existing behavior: capture still adds the lexeme to the dictionary, merges duplicates, queues translation, and keeps the menu bar popover available for settings/library/review.

## Implementation Plan

1. Add a capture result surface model.
   - Introduce an `OverlayState` in `AppModel` or a dedicated overlay coordinator.
   - Track captured text, lexeme id, translation state, source app, selection rect, and lifecycle state.

2. Resolve selection bounds.
   - For Accessibility capture, try `kAXBoundsForRangeParameterizedAttribute` with the selected text range when available.
   - If exact bounds fail, use focused element bounds.
   - For Services capture, use mouse location or menu bar fallback because Services pasteboard usually does not include selection geometry.
   - Log which positioning strategy was used.

3. Add native floating overlay.
   - Use an `NSPanel` or borderless `NSWindow` with SwiftUI content.
   - Configure it as non-activating where possible.
   - Keep it above normal windows without becoming disruptive.
   - Reuse one overlay window and update state rather than creating unbounded windows.

4. Integrate with translation queue.
   - Show overlay immediately after capture with a saved/loading state.
   - Update overlay when fallback translation is available.
   - Update again when Apple Translation UI completes.
   - Allow cancel current translation from overlay if translation is still running.

5. Keep menu bar as fallback/control.
   - Do not remove the current menu bar popover.
   - Settings can later include overlay enable/disable and fallback placement behavior.
   - Do not add a timed auto-dismiss setting; this overlay should not disappear purely because time elapsed.

## Test And Acceptance Plan

### Unit Tests

- Overlay state transitions:
  - idle -> saving -> translating -> translated -> dismissed
  - idle -> saving -> translationFailed
  - translating -> cancelled
- Placement strategy selection:
  - exact selection rect
  - focused element rect fallback
  - mouse/menu fallback
- Translation queue interaction:
  - multiple captures update the current overlay without dropping queued translations
  - cancelled translation advances queue
  - duplicate capture debounce does not show duplicate overlays

### Manual Integration Tests

- Safari or browser page text:
  - Services shortcut captures text.
  - Overlay appears near selected text or sensible fallback.
  - Translation updates without opening the menu bar popover as the primary UI.

- Preview PDF:
  - Selected text captures.
  - Overlay appears near selection when geometry is available.

- VS Code:
  - Services path may vary; advanced capture path should work when enabled.
  - Overlay should not steal editor focus.

- Codex app:
  - Advanced capture should work where Accessibility/clipboard fallback succeeds.
  - When geometry is unavailable, fallback placement should be stable.

- English Pocket Capture text editor:
  - Manual paste and save still works.
  - Overlay should not interfere with typing or buttons.

### Regression Tests

- Menu bar quit still works.
- Delete single lexeme and clear library still work.
- Translation task cancellation still works.
- `swift test` passes.
- `./scripts/build_macos_app.sh` succeeds.
- macOS 15 build compatibility is preserved.
- macOS 26-only direct Translation APIs remain availability-gated.

## Acceptance Criteria

- Capturing a word from a browser shows a compact overlay without requiring the user to open the menu bar popover.
- Capturing multiple words quickly does not drop translations.
- Overlay remains visible indefinitely until the user dismisses it.
- Overlay disappears when the user clicks/selects outside it or presses Escape.
- Long-running translation can be cancelled from a visible UI.
- If overlay positioning fails, the word is still saved and a fallback overlay appears.
- Logs clearly identify capture path, placement strategy, translation request id, and cancellation/failure when applicable.
