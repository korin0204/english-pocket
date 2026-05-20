import Foundation
import NaturalLanguage

#if canImport(Translation)
@preconcurrency import Translation
#endif

public protocol TranslationProviding: Sendable {
    func translate(_ text: String, sourceLanguage: String?, targetLanguage: String) async -> TranslationResult
}

public struct HybridTranslationService: TranslationProviding {
    private let fallback = LocalFallbackTranslationService()

    public init() {}

    public func translate(_ text: String, sourceLanguage: String? = "en", targetLanguage: String = "ja") async -> TranslationResult {
        let displayText = TextNormalizer.displayText(text)
        guard !displayText.isEmpty else {
            return TranslationResult(sourceText: text, targetText: "", targetLanguage: targetLanguage, provider: "empty")
        }

        #if canImport(Translation)
        if #available(macOS 26.0, *) {
            if let translated = await AppleTranslationService().translateIfInstalled(displayText, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage) {
                return translated
            }
        }
        #endif

        return await fallback.translate(displayText, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
    }
}

public struct LocalFallbackTranslationService: TranslationProviding {
    private let dictionary: [String: String] = [
        "abstract": "要約、抽象的な",
        "approach": "手法、取り組み",
        "assumption": "前提、仮定",
        "evaluate": "評価する",
        "evidence": "証拠、根拠",
        "feasible": "実現可能な",
        "hypothesis": "仮説",
        "implementation": "実装",
        "method": "方法、手法",
        "robust": "堅牢な",
        "significant": "重要な、有意な",
        "tradeoff": "トレードオフ"
    ]

    public init() {}

    public func translate(_ text: String, sourceLanguage: String? = "en", targetLanguage: String = "ja") async -> TranslationResult {
        let normalized = TextNormalizer.normalize(text)
        let targetText = dictionary[normalized] ?? "未翻訳: \(text)"
        return TranslationResult(
            sourceText: text,
            targetText: targetText,
            sourceLanguage: sourceLanguage ?? detectLanguageIdentifier(text),
            targetLanguage: targetLanguage,
            provider: dictionary[normalized] == nil ? "Local fallback" : "Local dictionary"
        )
    }
}

#if canImport(Translation)
@available(macOS 26.0, *)
private struct AppleTranslationService {
    func translateIfInstalled(_ text: String, sourceLanguage: String?, targetLanguage: String) async -> TranslationResult? {
        let sourceLanguage = sourceLanguage ?? detectLanguageIdentifier(text) ?? "en"

        let source = Locale.Language(identifier: sourceLanguage)
        let target = Locale.Language(identifier: targetLanguage)
        let availability = LanguageAvailability()
        let status = await availability.status(from: source, to: target)

        guard status == .installed else {
            return nil
        }

        do {
            let session = TranslationSession(installedSource: source, target: target)
            let response = try await session.translate(text)
            return TranslationResult(
                sourceText: response.sourceText,
                targetText: response.targetText,
                sourceLanguage: response.sourceLanguage.languageCode?.identifier,
                targetLanguage: response.targetLanguage.languageCode?.identifier ?? targetLanguage,
                provider: "Apple Translation"
            )
        } catch {
            return nil
        }
    }
}
#endif

private func detectLanguageIdentifier(_ text: String) -> String? {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    guard let language = recognizer.dominantLanguage, language != .undetermined else {
        return nil
    }
    return language.rawValue
}
