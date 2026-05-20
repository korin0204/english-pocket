import Foundation

public enum TextNormalizer {
    public static func normalize(_ text: String) -> String {
        cleaned(text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
    }

    public static func displayText(_ text: String) -> String {
        cleaned(text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func cleaned(_ text: String) -> String {
        String(text.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.contains(scalar)
        })
    }
}
