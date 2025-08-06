import QuickSummaryShared
import SwiftUI

class SettingsViewModel: ObservableObject {
    @Published var settingsService = SettingsService.shared
    @Published var usageTracker = UsageTrackerService.shared
    @Published var showingResetAlert = false
    @Published var languageSheetPresented = false
    @Published var languageSearchText = ""
    @Published var showCopyAlert = false
    @Published var showOnboarding = false

    // Supported summary languages
    var supportedLanguages: [(code: String, name: String)] {
        // Use all available language codes from Locale
        let codes: [String]
        if #available(iOS 16.0, *) {
            codes = Locale.LanguageCode.isoLanguageCodes.map { $0.identifier }
        } else {
            codes = Locale.isoLanguageCodes
        }
        let currentLocale = Locale.current
        return codes.compactMap { code -> (String, String)? in
            guard let name = currentLocale.localizedString(forLanguageCode: code) else {
                return nil
            }
            return (code, name.capitalized)
        }.sorted { $0.1 < $1.1 }
    }

    var filteredLanguages: [(code: String, name: String)] {
        if languageSearchText.isEmpty {
            return supportedLanguages
        } else {
            return supportedLanguages.filter {
                $0.name.localizedCaseInsensitiveContains(languageSearchText)
            }
        }
    }
}
