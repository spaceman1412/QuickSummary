import QuickSummaryShared
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var settingsService = SettingsService.shared
    @Published var usageTracker = UsageTrackerService.shared
    @Published var showingResetAlert = false
    @Published var languageSheetPresented = false
    @Published var languageSearchText = ""
    @Published var showCopyAlert = false
    @Published var showOnboarding = false

    // API Key management
    @Published var customAPIKey = ""
    @Published var apiKeyStatus: String?

    var apiKeyStatusIcon: String {
        guard let status = apiKeyStatus else { return "" }
        return status.contains("Valid") ? "checkmark.circle" : "exclamationmark.triangle"
    }

    var apiKeyStatusColor: Color {
        guard let status = apiKeyStatus else { return .secondary }
        return status.contains("Valid") ? .green : .red
    }

    var hasStoredAPIKey: Bool {
        KeychainService.shared.hasAPIKey()
    }

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

    // MARK: - API Key Management

    func saveAPIKey() {
        guard !customAPIKey.isEmpty else { return }

        // Dismiss keyboard
        hideKeyboard()

        // Show validating status
        apiKeyStatus = "Validating API key..."

        Task {
            do {
                // First save the key temporarily to test it
                try KeychainService.shared.saveAPIKey(customAPIKey)

                // Test the API key with a simple call
                let testResponse = try await GeminiAPIClient.shared.generateContent(
                    modelKey: "gemini-2.0-flash-001",
                    prompt: "Hi"
                )
                print(testResponse)

                if !testResponse.isEmpty {
                    await MainActor.run {
                        apiKeyStatus = "✓ Valid API key saved"
                        // Don't clear the field - keep it for user reference
                    }
                } else {
                    // Empty response might indicate an issue
                    await MainActor.run {
                        apiKeyStatus = "⚠ API key saved but got empty response"
                    }
                }
            } catch let error as GeminiAPIError {
                // Remove the invalid key from keychain
                try? KeychainService.shared.deleteAPIKey()
                await MainActor.run {
                    switch error {
                    case .invalidAPIKey:
                        apiKeyStatus = "✗ Invalid API key"
                    case .rateLimitExceeded:
                        apiKeyStatus = "⚠ Rate limit exceeded, but key saved"
                    case .networkError:
                        apiKeyStatus = "⚠ Network error, key saved (will retry later)"
                    default:
                        apiKeyStatus = "✗ API validation failed: \(error.localizedDescription)"
                    }
                }
            } catch {
                // Remove the invalid key from keychain
                try? KeychainService.shared.deleteAPIKey()
                await MainActor.run {
                    apiKeyStatus = "✗ Failed to validate API key: \(error.localizedDescription)"
                }
            }
        }
    }

    func clearAPIKey() {
        do {
            try KeychainService.shared.deleteAPIKey()
            apiKeyStatus = "API key cleared"
            customAPIKey = ""
        } catch {
            apiKeyStatus = "Failed to clear API key: \(error.localizedDescription)"
        }
    }
}
