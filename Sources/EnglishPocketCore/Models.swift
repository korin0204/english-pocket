import Foundation

public struct Lexeme: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var displayText: String
    public var normalizedText: String
    public var sourceLanguage: String?
    public var targetLanguage: String
    public var translation: String?
    public var translationProvider: String?
    public var note: String
    public var masteryScore: Double
    public var nextReviewAt: Date
    public var createdAt: Date
    public var updatedAt: Date
    public var occurrences: [Occurrence]
    public var reviewLogs: [ReviewLog]

    public init(
        id: UUID = UUID(),
        displayText: String,
        normalizedText: String,
        sourceLanguage: String? = nil,
        targetLanguage: String = "ja",
        translation: String? = nil,
        translationProvider: String? = nil,
        note: String = "",
        masteryScore: Double = 0,
        nextReviewAt: Date = Date(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        occurrences: [Occurrence] = [],
        reviewLogs: [ReviewLog] = []
    ) {
        self.id = id
        self.displayText = displayText
        self.normalizedText = normalizedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.translation = translation
        self.translationProvider = translationProvider
        self.note = note
        self.masteryScore = masteryScore
        self.nextReviewAt = nextReviewAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.occurrences = occurrences
        self.reviewLogs = reviewLogs
    }
}

public struct Occurrence: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var sourceApp: String
    public var sourceTitle: String
    public var surroundingText: String
    public var capturedAt: Date

    public init(
        id: UUID = UUID(),
        sourceApp: String = "",
        sourceTitle: String = "",
        surroundingText: String = "",
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.sourceApp = sourceApp
        self.sourceTitle = sourceTitle
        self.surroundingText = surroundingText
        self.capturedAt = capturedAt
    }
}

public struct ReviewLog: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var grade: ReviewGrade
    public var reviewedAt: Date
    public var latencyMilliseconds: Int?

    public init(
        id: UUID = UUID(),
        grade: ReviewGrade,
        reviewedAt: Date = Date(),
        latencyMilliseconds: Int? = nil
    ) {
        self.id = id
        self.grade = grade
        self.reviewedAt = reviewedAt
        self.latencyMilliseconds = latencyMilliseconds
    }
}

public enum ReviewGrade: String, Codable, CaseIterable, Sendable {
    case again
    case hard
    case good
    case easy
}

public struct CaptureRequest: Equatable, Sendable {
    public var text: String
    public var sourceApp: String
    public var sourceTitle: String
    public var surroundingText: String
    public var action: CaptureAction

    public init(
        text: String,
        sourceApp: String = "",
        sourceTitle: String = "",
        surroundingText: String = "",
        action: CaptureAction = .saveAndTranslate
    ) {
        self.text = text
        self.sourceApp = sourceApp
        self.sourceTitle = sourceTitle
        self.surroundingText = surroundingText
        self.action = action
    }
}

public enum CaptureAction: String, Codable, Sendable {
    case save
    case translate
    case saveAndTranslate
}

public struct CaptureResult: Equatable, Sendable {
    public var lexeme: Lexeme
    public var didCreate: Bool
    public var translation: TranslationResult?

    public init(lexeme: Lexeme, didCreate: Bool, translation: TranslationResult?) {
        self.lexeme = lexeme
        self.didCreate = didCreate
        self.translation = translation
    }
}

public struct TranslationResult: Codable, Equatable, Sendable {
    public var sourceText: String
    public var targetText: String
    public var sourceLanguage: String?
    public var targetLanguage: String
    public var provider: String

    public init(
        sourceText: String,
        targetText: String,
        sourceLanguage: String? = nil,
        targetLanguage: String = "ja",
        provider: String
    ) {
        self.sourceText = sourceText
        self.targetText = targetText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.provider = provider
    }
}

