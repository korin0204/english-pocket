import Foundation
import Testing
@testable import EnglishPocketCore

@Test func normalizerCollapsesWhitespaceAndCase() {
    #expect(TextNormalizer.normalize("  Résumé   REVIEW  ") == "resume review")
}

@Test func normalizerRemovesControlCharacters() {
    #expect(TextNormalizer.displayText("\u{03}") == "")
    #expect(TextNormalizer.normalize("\u{03} Robust") == "robust")
}

@Test func storeMergesDuplicateCaptures() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("lexemes.json")
    let store = LexemeStore(fileURL: url)
    _ = try await store.load()

    let first = try await store.capture(CaptureRequest(text: "Robust"))
    let second = try await store.capture(CaptureRequest(text: " robust "))

    #expect(first.didCreate)
    #expect(!second.didCreate)
    #expect(await store.all().count == 1)
    #expect(await store.all().first?.occurrences.count == 2)
}

@Test func reviewSchedulerMovesGoodCardToFuture() {
    let lexeme = Lexeme(displayText: "method", normalizedText: "method")
    let now = Date()
    let reviewed = ReviewScheduler.apply(.good, to: lexeme, at: now)

    #expect(reviewed.reviewLogs.count == 1)
    #expect(reviewed.nextReviewAt > now)
    #expect(reviewed.masteryScore > lexeme.masteryScore)
}

@Test func csvExportIncludesSavedLexeme() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("lexemes.json")
    let store = LexemeStore(fileURL: url)
    _ = try await store.load()
    _ = try await store.capture(
        CaptureRequest(text: "abstract"),
        translation: TranslationResult(sourceText: "abstract", targetText: "要約", provider: "Test")
    )

    let csv = await store.exportCSV()
    #expect(csv.contains("\"abstract\""))
    #expect(csv.contains("\"要約\""))
}

@Test func storeCanAttachTranslationAfterInitialCapture() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("lexemes.json")
    let store = LexemeStore(fileURL: url)
    _ = try await store.load()
    let captured = try await store.capture(CaptureRequest(text: "method"))

    let updated = try await store.updateTranslation(
        id: captured.lexeme.id,
        translation: TranslationResult(sourceText: "method", targetText: "方法", provider: "Apple Translation UI")
    )

    #expect(updated.translation == "方法")
    #expect(updated.translationProvider == "Apple Translation UI")
}

@Test func storeDeletesLexeme() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("lexemes.json")
    let store = LexemeStore(fileURL: url)
    _ = try await store.load()
    let captured = try await store.capture(CaptureRequest(text: "evidence"))

    try await store.delete(id: captured.lexeme.id)

    #expect(await store.all().isEmpty)
}

@Test func storeDeletesAllLexemes() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("lexemes.json")
    let store = LexemeStore(fileURL: url)
    _ = try await store.load()
    _ = try await store.capture(CaptureRequest(text: "evidence"))
    _ = try await store.capture(CaptureRequest(text: "approach"))

    try await store.deleteAll()

    #expect(await store.all().isEmpty)
}
