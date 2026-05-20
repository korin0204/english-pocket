import EnglishPocketCore
import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(model: model)
            TabView {
                CaptureView(model: model)
                    .tabItem {
                        Label("Capture", systemImage: "plus.circle")
                    }
                ReviewView(model: model)
                    .tabItem {
                        Label("Review", systemImage: "rectangle.stack")
                    }
                LibraryView(model: model)
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
                    }
                SettingsView(model: model)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
        }
        .frame(minWidth: 420, minHeight: 520)
    }
}

private struct HeaderView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack {
            Image(systemName: "text.badge.plus")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("English Pocket")
                    .font(.headline)
                Text(model.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(model.lexemes.count)")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .accessibilityLabel("Saved items")
            Button {
                model.quitApplication()
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit English Pocket")
        }
        .padding()
        .background(.bar)
    }
}

private struct CaptureView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $model.captureText)
                .font(.body)
                .frame(minHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.quaternary)
                )
            HStack {
                Button {
                    model.captureManualInput()
                } label: {
                    Label("Save + Translate", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    model.pasteClipboardIntoCaptureText()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .help("Paste clipboard text into Capture")

                Spacer()
            }

            if let translation = model.lastTranslation {
                TranslationCard(result: translation)
            }

            if let pending = model.pendingUITranslation {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Translating “\(pending.text)” with Apple Translation")
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}

private struct TranslationCard: View {
    let result: TranslationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.sourceText)
                .font(.headline)
            Text(result.targetText)
                .font(.title3)
                .textSelection(.enabled)
            HStack {
                Image(systemName: "sparkle.magnifyingglass")
                Text(result.provider)
                Spacer()
                Text(result.targetLanguage.uppercased())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ReviewView: View {
    @ObservedObject var model: AppModel
    @State private var lexemePendingDeletion: Lexeme?

    var body: some View {
        List {
            if model.dueLexemes.isEmpty {
                ContentUnavailableView("No reviews due", systemImage: "checkmark.circle")
            } else {
                ForEach(model.dueLexemes) { lexeme in
                    VStack(alignment: .leading, spacing: 8) {
                        LexemeSummary(lexeme: lexeme)
                        HStack {
                            ForEach(ReviewGrade.allCases, id: \.rawValue) { grade in
                                Button(grade.rawValue.capitalized) {
                                    model.review(lexeme, grade: grade)
                                }
                                .buttonStyle(.bordered)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                lexemePendingDeletion = lexeme
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Delete")
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .confirmationDialog(
            "Delete “\(lexemePendingDeletion?.displayText ?? "")”?",
            isPresented: Binding(
                get: { lexemePendingDeletion != nil },
                set: { if !$0 { lexemePendingDeletion = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let lexemePendingDeletion {
                    model.delete(lexemePendingDeletion)
                }
                lexemePendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                lexemePendingDeletion = nil
            }
        }
    }
}

private struct LibraryView: View {
    @ObservedObject var model: AppModel
    @State private var lexemePendingDeletion: Lexeme?

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search words, phrases, translations", text: $model.searchText)
                .textFieldStyle(.roundedBorder)
                .padding()
            List(model.filteredLexemes) { lexeme in
                HStack(alignment: .top, spacing: 8) {
                    LexemeSummary(lexeme: lexeme)
                    Button(role: .destructive) {
                        lexemePendingDeletion = lexeme
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Delete")
                }
                .padding(.vertical, 4)
                .contextMenu {
                    Button(role: .destructive) {
                        lexemePendingDeletion = lexeme
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete “\(lexemePendingDeletion?.displayText ?? "")”?",
            isPresented: Binding(
                get: { lexemePendingDeletion != nil },
                set: { if !$0 { lexemePendingDeletion = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let lexemePendingDeletion {
                    model.delete(lexemePendingDeletion)
                }
                lexemePendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                lexemePendingDeletion = nil
            }
        }
    }
}

private struct LexemeSummary: View {
    let lexeme: Lexeme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(lexeme.displayText)
                    .font(.headline)
                Spacer()
                Text("\(lexeme.occurrences.count)x")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let translation = lexeme.translation {
                Text(translation)
                    .foregroundStyle(.primary)
            }
            HStack {
                ProgressView(value: lexeme.masteryScore)
                    .frame(width: 90)
                Text("Next \(lexeme.nextReviewAt.formatted(date: .abbreviated, time: .shortened))")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var confirmClearLibrary = false

    var body: some View {
        Form {
            Section("Translation") {
                Picker("Source language", selection: $model.sourceLanguage) {
                    Text("English").tag("en")
                    Text("Japanese").tag("ja")
                    Text("Korean").tag("ko")
                    Text("Chinese").tag("zh-Hans")
                }

                Picker("Target language", selection: $model.targetLanguage) {
                    Text("Japanese").tag("ja")
                    Text("English").tag("en")
                    Text("Korean").tag("ko")
                    Text("Chinese").tag("zh-Hans")
                }
            }

            Section("App") {
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )

                Button {
                    model.quitApplication()
                } label: {
                    Label("Quit English Pocket", systemImage: "power")
                }
            }

            Section("Data") {
                Button {
                    model.exportCSVToDesktop()
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    confirmClearLibrary = true
                } label: {
                    Label("Clear Library", systemImage: "trash")
                }

                SettingsPathRow(label: "Storage", value: model.storagePath)
                SettingsPathRow(label: "Log", value: model.logPath)
            }

            Section("Capture") {
                Toggle("Enable advanced global capture", isOn: $model.globalCaptureEnabled)

                HStack {
                    Label(
                        model.accessibilityTrusted ? "Accessibility enabled" : "Accessibility not enabled",
                        systemImage: model.accessibilityTrusted ? "checkmark.shield" : "exclamationmark.triangle"
                    )
                    Spacer()
                    Button("Refresh") {
                        model.refreshAccessibilityStatus()
                    }
                }

                Button {
                    model.requestAccessibilityPermission()
                } label: {
                    Label("Request Accessibility Access", systemImage: "lock.open")
                }
                .disabled(!model.globalCaptureEnabled)

                Text("Default capture uses the macOS Service shortcut you assign in System Settings. Advanced global capture is optional, takes effect after relaunch, and uses Ctrl+Option+Shift+C to reduce conflicts; it tries Accessibility selected text, then a clipboard fallback.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Enable the Service named “Save to English Pocket” in System Settings > Keyboard > Keyboard Shortcuts > Services, then assign your preferred shortcut.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .onAppear {
            model.refreshLaunchAtLoginStatus()
            model.refreshAccessibilityStatus()
        }
        .confirmationDialog("Clear all saved words?", isPresented: $confirmClearLibrary) {
            Button("Clear Library", role: .destructive) {
                model.deleteAll()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct SettingsPathRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }
}
