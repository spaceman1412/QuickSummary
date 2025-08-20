import Foundation
import QuickSummaryShared

private let whatsNewKey = "whatsNew_lastShownVersion"

func shouldShowWhatsNew(version: String) -> Bool {
    let ud = UserDefaults(suiteName: AppConstants.AppGroups.identifier) ?? .standard
    let last = ud.string(forKey: whatsNewKey)
    return last != version
}

func markWhatsNewShown(version: String) {
    let ud = UserDefaults(suiteName: AppConstants.AppGroups.identifier) ?? .standard
    ud.set(version, forKey: whatsNewKey)
}
