import Foundation
import StoreKit

@MainActor
public final class ReviewRequestService: ObservableObject {
    public static let shared = ReviewRequestService()

    private let userDefaults: UserDefaults

    private enum Keys {
        static let lastPromptedDate = "review_lastPromptedDate"
        static let baselineSummariesCount = "review_baselineSummariesCount"
    }

    private init() {
        userDefaults = UserDefaults(suiteName: AppConstants.AppGroups.identifier) ?? .standard
    }

    private var lastPromptedDate: Date? {
        get { userDefaults.object(forKey: Keys.lastPromptedDate) as? Date }
        set { userDefaults.set(newValue, forKey: Keys.lastPromptedDate) }
    }

    private var baselineSummariesCount: Int? {
        get {
            let value = userDefaults.object(forKey: Keys.baselineSummariesCount) as? NSNumber
            return value?.intValue
        }
        set {
            userDefaults.set(newValue, forKey: Keys.baselineSummariesCount)
        }
    }

    public func shouldPrompt(totalSummaries: Int) -> Bool {
        // Safety floor: never prompt below global minimum
        guard totalSummaries >= AppConstants.Review.minSummariesForPrompt else { return false }

        // Lazy initialize baseline on first-ever summary or for existing users post-update
        if baselineSummariesCount == nil {
            if totalSummaries > 0 { baselineSummariesCount = totalSummaries }
            return false
        }

        let additionalSinceBaseline = max(0, totalSummaries - (baselineSummariesCount ?? 0))
        guard additionalSinceBaseline >= 3 else { return false }

        if let last = lastPromptedDate {
            let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            if days < AppConstants.Review.cooldownDays { return false }
        }

        return true
    }

    public func markPromptShown() {
        lastPromptedDate = Date()
        // Advance baseline so next prompt requires +5 more summaries
        let currentTotals = UsageTrackerService.shared.totalSummariesCreated
        baselineSummariesCount = currentTotals
    }

    public func markUserTappedRate() {
        markPromptShown()
    }

    #if !os(macOS)
        public func tryPromptInAppIfEligible(windowScene: UIWindowScene?) {
            let totals = UsageTrackerService.shared.totalSummariesCreated
            guard let scene = windowScene else { return }
            if shouldPrompt(totalSummaries: totals) {
                SKStoreReviewController.requestReview(in: scene)
                markPromptShown()
            }
        }
    #endif

    public func shouldShowExtensionCTA(totalSummaries: Int) -> Bool {
        shouldPrompt(totalSummaries: totalSummaries)
    }

    public func appStoreReviewURL() -> URL? {
        AppConstants.Review.appStoreWriteReviewURL
    }
}
