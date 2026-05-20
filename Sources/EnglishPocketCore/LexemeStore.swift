import Foundation

public actor LexemeStore {
    private let fileURL: URL
    private var lexemes: [Lexeme] = []

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.fileURL = base.appendingPathComponent("EnglishPocket/lexemes.json", isDirectory: false)
        }
    }

    public func load() throws -> [Lexeme] {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            lexemes = []
            return []
        }

        let data = try Data(contentsOf: fileURL)
        lexemes = try JSONDecoder.englishPocket.decode([Lexeme].self, from: data)
        return lexemes
    }

    public func all() -> [Lexeme] {
        lexemes.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func due(at date: Date = Date()) -> [Lexeme] {
        lexemes
            .filter { $0.nextReviewAt <= date }
            .sorted { $0.nextReviewAt < $1.nextReviewAt }
    }

    public func capture(_ request: CaptureRequest, translation: TranslationResult? = nil) throws -> CaptureResult {
        let displayText = TextNormalizer.displayText(request.text)
        let normalized = TextNormalizer.normalize(displayText)

        guard !normalized.isEmpty else {
            throw LexemeStoreError.emptyText
        }

        let occurrence = Occurrence(
            sourceApp: request.sourceApp,
            sourceTitle: request.sourceTitle,
            surroundingText: request.surroundingText
        )

        if let index = lexemes.firstIndex(where: { $0.normalizedText == normalized }) {
            var existing = lexemes[index]
            existing.displayText = displayText
            existing.occurrences.append(occurrence)
            existing.updatedAt = Date()
            if let translation {
                existing.translation = translation.targetText
                existing.translationProvider = translation.provider
                existing.sourceLanguage = translation.sourceLanguage
                existing.targetLanguage = translation.targetLanguage
            }
            lexemes[index] = existing
            try save()
            return CaptureResult(lexeme: existing, didCreate: false, translation: translation)
        }

        let lexeme = Lexeme(
            displayText: displayText,
            normalizedText: normalized,
            sourceLanguage: translation?.sourceLanguage,
            targetLanguage: translation?.targetLanguage ?? "ja",
            translation: translation?.targetText,
            translationProvider: translation?.provider,
            occurrences: [occurrence]
        )
        lexemes.append(lexeme)
        try save()
        return CaptureResult(lexeme: lexeme, didCreate: true, translation: translation)
    }

    public func update(_ lexeme: Lexeme) throws {
        guard let index = lexemes.firstIndex(where: { $0.id == lexeme.id }) else {
            throw LexemeStoreError.notFound
        }
        lexemes[index] = lexeme
        try save()
    }

    public func updateTranslation(id: UUID, translation: TranslationResult) throws -> Lexeme {
        guard let index = lexemes.firstIndex(where: { $0.id == id }) else {
            throw LexemeStoreError.notFound
        }

        var lexeme = lexemes[index]
        lexeme.translation = translation.targetText
        lexeme.translationProvider = translation.provider
        lexeme.sourceLanguage = translation.sourceLanguage
        lexeme.targetLanguage = translation.targetLanguage
        lexeme.updatedAt = Date()
        lexemes[index] = lexeme
        try save()
        return lexeme
    }

    public func delete(id: UUID) throws {
        guard let index = lexemes.firstIndex(where: { $0.id == id }) else {
            throw LexemeStoreError.notFound
        }
        lexemes.remove(at: index)
        try save()
    }

    public func deleteAll() throws {
        lexemes.removeAll()
        try save()
    }

    public func review(id: UUID, grade: ReviewGrade, at date: Date = Date()) throws -> Lexeme {
        guard let index = lexemes.firstIndex(where: { $0.id == id }) else {
            throw LexemeStoreError.notFound
        }
        let updated = ReviewScheduler.apply(grade, to: lexemes[index], at: date)
        lexemes[index] = updated
        try save()
        return updated
    }

    public func exportCSV() -> String {
        var rows = ["Text,Translation,Provider,Mastery,Next Review,Created,Occurrences"]
        let formatter = ISO8601DateFormatter()
        for lexeme in lexemes.sorted(by: { $0.createdAt < $1.createdAt }) {
            rows.append([
                lexeme.displayText,
                lexeme.translation ?? "",
                lexeme.translationProvider ?? "",
                String(format: "%.2f", lexeme.masteryScore),
                formatter.string(from: lexeme.nextReviewAt),
                formatter.string(from: lexeme.createdAt),
                String(lexeme.occurrences.count)
            ].map(csvEscape).joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    private func save() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.englishPocket.encode(lexemes)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

public enum LexemeStoreError: LocalizedError, Equatable {
    case emptyText
    case notFound

    public var errorDescription: String? {
        switch self {
        case .emptyText:
            "No text was provided."
        case .notFound:
            "The saved item no longer exists."
        }
    }
}

private extension JSONEncoder {
    static var englishPocket: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var englishPocket: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
