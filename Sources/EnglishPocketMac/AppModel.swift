import AppKit
import EnglishPocketCore
import Foundation
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var lexemes: [Lexeme] = []
    @Published private(set) var dueLexemes: [Lexeme] = []
    @Published private(set) var pendingUITranslation: UITranslationRequest?
    @Published private(set) var translationQueueCount: Int = 0
    @Published var captureText: String = ""
    @Published var searchText: String = ""
    @Published var statusMessage: String = "Ready"
    @Published var lastTranslation: TranslationResult?
    @Published var launchAtLogin: Bool = false
    @Published var accessibilityTrusted: Bool = false
    @Published var globalCaptureEnabled: Bool {
        didSet {
            UserDefaults.standard.set(globalCaptureEnabled, forKey: Self.globalCaptureEnabledKey)
        }
    }
    @Published var sourceLanguage: String {
        didSet {
            UserDefaults.standard.set(sourceLanguage, forKey: Self.sourceLanguageKey)
        }
    }
    @Published var targetLanguage: String {
        didSet {
            UserDefaults.standard.set(targetLanguage, forKey: Self.targetLanguageKey)
        }
    }

    private static let sourceLanguageKey = "sourceLanguage"
    private static let targetLanguageKey = "targetLanguage"
    private static let globalCaptureEnabledKey = "globalCaptureEnabled"
    private let store = LexemeStore()
    private let translator = HybridTranslationService()
    private let logger = AppLogger(category: "Translation")
    private var queuedUITranslations: [UITranslationRequest] = []
    private var lastCaptureKey: String?
    private var lastCaptureDate = Date.distantPast
    let storagePath = "~/Library/Application Support/EnglishPocket/lexemes.json"
    let logPath = "~/Library/Application Support/EnglishPocket/EnglishPocket.log"

    init() {
        sourceLanguage = UserDefaults.standard.string(forKey: Self.sourceLanguageKey) ?? "en"
        targetLanguage = UserDefaults.standard.string(forKey: Self.targetLanguageKey) ?? "ja"
        globalCaptureEnabled = UserDefaults.standard.bool(forKey: Self.globalCaptureEnabledKey)
        refreshLaunchAtLoginStatus()
        refreshAccessibilityStatus()
    }

    var filteredLexemes: [Lexeme] {
        let query = TextNormalizer.normalize(searchText)
        guard !query.isEmpty else { return lexemes }
        return lexemes.filter {
            $0.normalizedText.contains(query)
                || TextNormalizer.normalize($0.translation ?? "").contains(query)
        }
    }

    func load() {
        Task {
            do {
                let loaded = try await store.load()
                lexemes = loaded.sorted { $0.updatedAt > $1.updatedAt }
                dueLexemes = await store.due()
                statusMessage = "Loaded \(loaded.count) items"
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func captureManualInput() {
        let request = CaptureRequest(text: captureText, sourceApp: "English Pocket", action: .saveAndTranslate)
        Task {
            await capture(request)
            captureText = ""
        }
    }

    func capture(_ request: CaptureRequest) async {
        let text = TextNormalizer.displayText(request.text)
        guard !text.isEmpty else {
            statusMessage = "Enter a word or phrase"
            return
        }

        statusMessage = "Saving..."
        if shouldDebounce(text) {
            statusMessage = "Already captured"
            return
        }

        let translation: TranslationResult?
        if #available(macOS 26.0, *) {
            statusMessage = "Translating..."
            translation = await translator.translate(text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        } else {
            translation = await translator.translate(text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        }

        do {
            let result = try await store.capture(request, translation: translation)
            lastTranslation = translation
            lexemes = await store.all()
            dueLexemes = await store.due()
            if #available(macOS 26.0, *) {
                statusMessage = result.didCreate ? "Saved: \(result.lexeme.displayText)" : "Updated: \(result.lexeme.displayText)"
            } else {
                enqueueUITranslation(
                    UITranslationRequest(
                        lexemeID: result.lexeme.id,
                        text: result.lexeme.displayText,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage
                    )
                )
                statusMessage = "Saved. Translating in the app..."
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func shouldDebounce(_ text: String) -> Bool {
        let key = TextNormalizer.normalize(text)
        let now = Date()
        defer {
            lastCaptureKey = key
            lastCaptureDate = now
        }
        return lastCaptureKey == key && now.timeIntervalSince(lastCaptureDate) < 0.8
    }

    private func enqueueUITranslation(_ request: UITranslationRequest) {
        logger.write("Queued UI translation \(request.id.uuidString) for \(request.text)")
        guard pendingUITranslation != nil else {
            pendingUITranslation = request
            translationQueueCount = queuedUITranslations.count
            logger.write("Started UI translation \(request.id.uuidString) for \(request.text)")
            return
        }

        queuedUITranslations.append(request)
        translationQueueCount = queuedUITranslations.count
        logger.write("Deferred UI translation \(request.id.uuidString); queue depth \(queuedUITranslations.count)")
    }

    func applyUITranslation(_ translation: TranslationResult, requestID: UUID) {
        guard let pending = pendingUITranslation, pending.id == requestID else { return }
        let lexemeID = pending.lexemeID
        Task {
            do {
                logger.write("Applying UI translation for \(pending.text): \(translation.targetText)")
                _ = try await store.updateTranslation(id: lexemeID, translation: translation)
                lastTranslation = translation
                lexemes = await store.all()
                dueLexemes = await store.due()
                statusMessage = "Translated with Apple Translation"
                advanceUITranslationQueue(after: requestID)
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func pasteClipboardIntoCaptureText() {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            statusMessage = "Clipboard does not contain text"
            return
        }

        let cleaned = TextNormalizer.displayText(text)
        guard !cleaned.isEmpty else {
            statusMessage = "Clipboard text is empty"
            return
        }

        if captureText.isEmpty {
            captureText = cleaned
        } else {
            captureText += captureText.hasSuffix(" ") || captureText.hasSuffix("\n") ? cleaned : " \(cleaned)"
        }
        statusMessage = "Pasted from clipboard"
    }

    func failUITranslation(_ error: Error, requestID: UUID) {
        guard pendingUITranslation?.id == requestID else { return }
        logger.write("UI translation failed: \(error.localizedDescription)")
        statusMessage = "Saved. Translation unavailable: \(error.localizedDescription)"
        advanceUITranslationQueue(after: requestID)
    }

    private func advanceUITranslationQueue(after requestID: UUID) {
        guard pendingUITranslation?.id == requestID else { return }
        pendingUITranslation = nil

        guard !queuedUITranslations.isEmpty else {
            translationQueueCount = 0
            return
        }

        let next = queuedUITranslations.removeFirst()
        translationQueueCount = queuedUITranslations.count
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingUITranslation = next
            self.logger.write("Started queued UI translation \(next.id.uuidString) for \(next.text); queue depth \(self.queuedUITranslations.count)")
        }
    }

    func cancelCurrentUITranslation() {
        guard let pending = pendingUITranslation else { return }
        logger.write("Cancelled UI translation \(pending.id.uuidString) for \(pending.text)")
        statusMessage = "Translation cancelled"
        advanceUITranslationQueue(after: pending.id)
    }

    func cancelAllUITranslations() {
        if let pendingUITranslation {
            logger.write("Cancelled current UI translation \(pendingUITranslation.id.uuidString) for \(pendingUITranslation.text)")
        }
        logger.write("Cleared \(queuedUITranslations.count) queued UI translations")
        pendingUITranslation = nil
        queuedUITranslations.removeAll()
        translationQueueCount = 0
        statusMessage = "Translation tasks cancelled"
    }

    func review(_ lexeme: Lexeme, grade: ReviewGrade) {
        Task {
            do {
                _ = try await store.review(id: lexeme.id, grade: grade)
                lexemes = await store.all()
                dueLexemes = await store.due()
                statusMessage = "Review saved"
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func delete(_ lexeme: Lexeme) {
        Task {
            do {
                try await store.delete(id: lexeme.id)
                lexemes = await store.all()
                dueLexemes = await store.due()
                statusMessage = "Deleted: \(lexeme.displayText)"
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func deleteAll() {
        Task {
            do {
                try await store.deleteAll()
                lexemes = []
                dueLexemes = []
                lastTranslation = nil
                pendingUITranslation = nil
                queuedUITranslations.removeAll()
                translationQueueCount = 0
                statusMessage = "Library cleared"
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func exportCSVToDesktop() {
        Task {
            let csv = await store.exportCSV()
            do {
                let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                let url = desktop.appendingPathComponent("EnglishPocketExport.csv")
                try csv.write(to: url, atomically: true, encoding: .utf8)
                statusMessage = "Exported to Desktop"
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func refreshAccessibilityStatus() {
        accessibilityTrusted = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshAccessibilityStatus()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                statusMessage = "Launch at login enabled"
            } else {
                try SMAppService.mainApp.unregister()
                statusMessage = "Launch at login disabled"
            }
        } catch {
            statusMessage = error.localizedDescription
        }
        refreshLaunchAtLoginStatus()
    }

    func quitApplication() {
        NSApp.terminate(nil)
    }
}

struct UITranslationRequest: Identifiable, Equatable {
    let id = UUID()
    var lexemeID: UUID
    var text: String
    var sourceLanguage: String
    var targetLanguage: String
}
