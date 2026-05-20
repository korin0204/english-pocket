# Repository Instructions

## Product Principles

- Keep the product native-first. macOS uses Swift, SwiftUI, and AppKit; iOS uses Swift, SwiftUI, and UIKit extensions where needed.
- Do not introduce Electron, React Native, Flutter, or WebView-centered UI.
- Windows is a future native add-on after the Apple product is mature; do not distort Apple-platform design for Windows reuse.
- Optimize workflows per OS. Share durable contracts such as data models, sync semantics, backend APIs, and learning algorithms.

## UX Rules

- For every creation/addition path, provide a corresponding deletion/removal path in the same milestone.
- Menu bar residency must always include a discoverable way to quit the app.
- Settings must be a real product surface, not only a debug panel. User-facing preferences and operational controls belong there.
- Destructive actions require confirmation in the UI.
- Keep capture lightweight: saving a word or phrase should never require navigating away from the current reading context.
- Inline translation should appear near the user's selected text when possible; the menu bar popover is a fallback/control surface, not the primary reading-time result surface.
- Treat macOS Services as the stable default capture path. Advanced global capture must be opt-in because app keybindings and user shortcuts can conflict.
- Long-running or failure-prone background work must be visible in the UI and cancellable when practical.

## Engineering Rules

- Prefer small, native abstractions over broad cross-platform layers.
- Keep Milestone 0 and 1 local-first; CloudKit/Core Data migration belongs to the Apple ecosystem milestone.
- Preserve macOS 15 compatibility unless a feature is explicitly gated behind a newer OS check.
- macOS 26-only translation APIs must stay behind availability checks.
- Keep tests for storage, normalization, deletion, and review scheduling behavior.
- Internal quality work must run in parallel with feature work. Do not postpone test coverage, diagnostics, or refactoring needed for stability until after feature completion.
- Every feature plan must define progressive pass conditions before implementation: unit tests, integration/manual scenarios, regression checks, and explicit acceptance criteria.
- Test cases should cover success, failure, cancellation, duplicate input, permission-denied states, OS-version differences, and user workflow regressions.
- Stability is a product requirement. Prefer deterministic state machines, queues, and explicit lifecycle ownership over implicit SwiftUI/AppKit side effects.
- Capture changes must consider app keybinding conflicts, Accessibility permission state, clipboard preservation, and duplicate capture debouncing.
- macOS Translation framework work must account for SwiftUI task lifecycle. Avoid hidden shared translation tasks for repeated requests; prefer request-scoped task views or an explicit queue.
- Any feature that depends on OS permissions, Services, Accessibility, pasteboard, or app focus must include diagnostics/logging hooks.

## Agent Workflow

- Split substantial work into three roles to keep context clean:
  - Planner: clarifies intent, designs scope, identifies risks, and writes the implementation plan.
  - Implementer: makes the code changes according to the plan and keeps edits scoped.
  - Verification Reviewer: reviews behavior, runs tests/builds, checks UX regressions, and looks for missing delete/quit/settings paths.
- The planner must not silently let implementation details drift away from native-first product principles.
- The implementer should not expand scope beyond the accepted plan without calling it out.
- The verification reviewer should be skeptical and prioritize bugs, regressions, missing tests, OS-version compatibility, and lifecycle gaps.
- The verification reviewer must maintain an explicit checklist of pass/fail conditions for each milestone and should block completion when core workflows are untested.
- For small mechanical edits, one agent may perform all roles, but the final response must still report planning, implementation, and verification outcomes separately.
