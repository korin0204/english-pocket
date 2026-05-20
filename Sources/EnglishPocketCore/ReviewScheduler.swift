import Foundation

public enum ReviewScheduler {
    public static func apply(_ grade: ReviewGrade, to lexeme: Lexeme, at reviewedAt: Date = Date()) -> Lexeme {
        var updated = lexeme
        let interval = intervalForNextReview(grade: grade, reviewCount: lexeme.reviewLogs.count, masteryScore: lexeme.masteryScore)
        updated.nextReviewAt = reviewedAt.addingTimeInterval(interval)
        updated.masteryScore = nextMasteryScore(current: lexeme.masteryScore, grade: grade)
        updated.reviewLogs.append(ReviewLog(grade: grade, reviewedAt: reviewedAt))
        updated.updatedAt = reviewedAt
        return updated
    }

    public static func intervalForNextReview(grade: ReviewGrade, reviewCount: Int, masteryScore: Double) -> TimeInterval {
        switch grade {
        case .again:
            return 10 * 60
        case .hard:
            return max(30 * 60, Double(reviewCount + 1) * 60 * 60)
        case .good:
            let days = max(1, min(30, Int(pow(2.0, Double(reviewCount)))))
            return TimeInterval(days * 24 * 60 * 60)
        case .easy:
            let days = max(3, min(90, Int(pow(2.4, Double(reviewCount + 1)))))
            return TimeInterval(days * 24 * 60 * 60)
        }
    }

    private static func nextMasteryScore(current: Double, grade: ReviewGrade) -> Double {
        let delta: Double
        switch grade {
        case .again:
            delta = -0.25
        case .hard:
            delta = 0.05
        case .good:
            delta = 0.18
        case .easy:
            delta = 0.3
        }
        return min(1, max(0, current + delta))
    }
}

