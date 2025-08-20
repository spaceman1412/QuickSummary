import Foundation
import StoreKit

@MainActor
public final class ReviewRequestService: ObservableObject {
    public static let shared = ReviewRequestService()

    private let userDefaults: UserDefaults

    private enum Keys {
        static let lastPromptedDate = "review_lastPromptedDate"
    }

    private init() {
        userDefaults = UserDefaults(suiteName: AppConstants.AppGroups.identifier) ?? .standard
    }

    private var lastPromptedDate: Date? {
        get { userDefaults.object(forKey: Keys.lastPromptedDate) as? Date }
        set { userDefaults.set(newValue, forKey: Keys.lastPromptedDate) }
    }

    public func shouldPrompt(totalSummaries: Int) -> Bool {
        guard totalSummaries >= AppConstants.Review.minSummariesForPrompt else { return false }

        if let last = lastPromptedDate {
            let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            if days < AppConstants.Review.cooldownDays { return false }
        }

        return true
    }

    public func markPromptShown() {
        lastPromptedDate = Date()
    }

    public func markUserTappedRate() {
        markPromptShown()
    }

    #if !os(macOS)
        public func tryPromptInAppIfEligible(windowScene: UIWindowScene?) {
            let totals = UsageTrackerService.shared.totalSummariesCreated
            guard shouldPrompt(totalSummaries: totals) else { return }
            guard let scene = windowScene else { return }
            SKStoreReviewController.requestReview(in: scene)
            markPromptShown()
        }
    #endif

    public func shouldShowExtensionCTA(totalSummaries: Int) -> Bool {
        shouldPrompt(totalSummaries: totalSummaries)
    }

    public func appStoreReviewURL() -> URL? {
        AppConstants.Review.appStoreWriteReviewURL
    }
}
