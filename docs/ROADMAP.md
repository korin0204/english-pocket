# English Pocket Roadmap

## Native-First Rules

- macOS is Swift, SwiftUI, and AppKit.
- iOS and iPadOS are Swift, SwiftUI, and UIKit extensions where needed.
- Electron, React Native, Flutter, and WebView-centered implementations are out of scope.
- Windows can be added after the Apple platform product is mature, but it must be native to Windows.
- Cross-platform sharing is limited to durable contracts: data models, sync semantics, backend APIs, and learning algorithms.
- UI and capture workflows should be optimized per OS, not forced into one shared abstraction.

## Current Target

The current implementation covers the beginning of Milestone 0 and Milestone 1:

- macOS 15+ menu bar app
- Services-based selected text capture
- Manual capture
- Local-first storage
- Translation provider boundary
- Apple Translation-first strategy: direct translation on macOS 26+, in-UI translation on macOS 15-25, and local fallback for prototype gaps
- Lightweight review queue
- CSV export

## Milestones

### 0. Feasibility Prototype

Validate whether selected text can be captured, saved, translated, and displayed quickly enough to feel natural while reading.

### 1. Private Mac MVP

Make the Mac app useful every day: fast capture, duplicate merge, search, review queue, settings, and export.

### 2. Alpha Apple Ecosystem

Add Core Data and CloudKit sync, an iOS companion app, iOS Share Extension, shared review history, and early LLM enrichment.

### 3. Paid v1

Add StoreKit 2 subscriptions, Free and Pro gates, backend LLM proxy, privacy policy, terms, purchase restore, and App Review readiness.

### 4. Pro Mac Native Experience

Add a notarized Mac helper, Accessibility-based capture, global shortcuts, overlay placement, app-specific capture improvements, and Raycast or Alfred integration.

### 5. Learning Intelligence

Add FSRS-style scheduling, weakness analysis, contextual cloze questions, generated examples, vocabulary clusters, and article-level word sets.

### 6. Apple Platform Completion

Add Safari Extension, Shortcuts, iPad review optimization, widgets, notifications, stats, and export integrations.

### 7. Windows Native Add-on

After the Apple product is mature, add a native Windows app using the best Windows-native stack at that time, such as .NET, WinUI, or Windows App SDK.
