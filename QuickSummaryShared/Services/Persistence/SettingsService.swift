import Foundation
import SwiftData

@MainActor
public class SettingsService: ObservableObject {
  public static let shared = SettingsService()

  private static let aiModelKey = "selectedAIModel"
  private static let summaryStyleKey = "selectedSummaryStyle"
  private static let summaryLengthKey = "selectedSummaryLength"
  private static let modelSelectionModeKey = "modelSelectionMode"
  private static let languageSelectionModeKey = "languageSelectionMode"
  private static let aiBackendModeKey = "aiBackendMode"

  private let userDefaults: UserDefaults

  // Keys for UserDefaults
  private enum Keys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let summaryLanguage = "summaryLanguage"
    static let summaryLength = "selectedSummaryLength"
    static let whatsNewLastShownVersion = "whatsNew_lastShownVersion"
  }

  @Published public var summaryLanguage: String {
    didSet {
      userDefaults.set(summaryLanguage, forKey: Keys.summaryLanguage)
    }
  }

  @Published public var selectedAIModel: AIModel {
    didSet {
      UserDefaults(suiteName: AppConstants.AppGroups.identifier)?.set(
        selectedAIModel.rawValue, forKey: SettingsService.aiModelKey)
    }
  }

  @Published public var modelSelectionMode: ModelSelectionMode {
    didSet {
      userDefaults.set(modelSelectionMode.rawValue, forKey: SettingsService.modelSelectionModeKey)
    }
  }

  @Published public var languageSelectionMode: LanguageSelectionMode {
    didSet {
      userDefaults.set(
        languageSelectionMode.rawValue, forKey: SettingsService.languageSelectionModeKey)
      // Sync summaryLanguage only on meaningful transitions
      if languageSelectionMode == .manual {
        // If coming from auto and language is currently auto, initialize to device default
        if summaryLanguage == "auto" {
          summaryLanguage = SettingsService.defaultLanguageCode()
        }
      } else {
        // Auto mode always uses sentinel "auto"
        summaryLanguage = "auto"
      }
    }
  }

  @Published public var selectedSummaryStyle: SummaryStyle {
    didSet {
      UserDefaults(suiteName: AppConstants.AppGroups.identifier)?.set(
        selectedSummaryStyle.rawValue, forKey: SettingsService.summaryStyleKey)
    }
  }

  @Published public var selectedSummaryLength: SummaryLength {
    didSet {
      userDefaults.set(selectedSummaryLength.rawValue, forKey: SettingsService.Keys.summaryLength)
    }
  }

  @Published public var aiBackendMode: AIBackendMode {
    didSet {
      userDefaults.set(aiBackendMode.rawValue, forKey: SettingsService.aiBackendModeKey)
    }
  }

  // MARK: - Onboarding
  @Published public var hasCompletedOnboarding: Bool {
    didSet {
      userDefaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
    }
  }

  private init() {
    guard let userDefaults = UserDefaults(suiteName: AppConstants.AppGroups.identifier) else {
      fatalError("Could not initialize UserDefaults with app group")
    }
    self.userDefaults = userDefaults

    // Initialize onboarding state first
    self.hasCompletedOnboarding = userDefaults.bool(forKey: Keys.hasCompletedOnboarding)

    // Initialize with defaults
    self.summaryLanguage = SettingsService.defaultLanguageCode()
    self.selectedAIModel = .gemini20FlashLite
    self.modelSelectionMode = .smart
    self.languageSelectionMode = .auto
    self.selectedSummaryStyle = .default
    self.selectedSummaryLength = .medium
    self.aiBackendMode = .managedFirebase

    // Load saved values
    self.summaryLanguage = loadSummaryLanguage()
    self.selectedAIModel = loadSelectedAIModel()
    self.selectedSummaryStyle = loadSelectedSummaryStyle()
    self.selectedSummaryLength = loadSelectedSummaryLength()
    self.modelSelectionMode = loadModelSelectionMode()
    self.languageSelectionMode = loadLanguageSelectionMode()
    self.aiBackendMode = loadAIBackendMode()
  }

  // MARK: - Methods
  public func refreshSettings() {
    summaryLanguage = loadSummaryLanguage()
    selectedAIModel = loadSelectedAIModel()
    selectedSummaryStyle = loadSelectedSummaryStyle()
    selectedSummaryLength = loadSelectedSummaryLength()
    modelSelectionMode = loadModelSelectionMode()
    languageSelectionMode = loadLanguageSelectionMode()
    aiBackendMode = loadAIBackendMode()
  }

  // MARK: - What's New gating
  public func shouldShowWhatsNew(for version: String) -> Bool {
    let last = userDefaults.string(forKey: Keys.whatsNewLastShownVersion)
    return last != version
  }

  public func markWhatsNewShown(version: String) {
    userDefaults.set(version, forKey: Keys.whatsNewLastShownVersion)
  }

  public func markOnboardingCompleted() {
    hasCompletedOnboarding = true
  }

  private func resetToDefaults() {
    summaryLanguage = SettingsService.defaultLanguageCode()
    selectedAIModel = .gemini20FlashLite
    selectedSummaryStyle = .default
    selectedSummaryLength = .medium
    modelSelectionMode = .smart
    languageSelectionMode = .auto
    aiBackendMode = .managedFirebase
  }

  private func loadSummaryLanguage() -> String {
    userDefaults.string(forKey: Keys.summaryLanguage) ?? SettingsService.defaultLanguageCode()
  }

  private func loadSelectedAIModel() -> AIModel {
    let raw = UserDefaults(suiteName: AppConstants.AppGroups.identifier)?.string(
      forKey: SettingsService.aiModelKey)
    return AIModel(rawValue: raw ?? "gemini-2.0-flash-lite-001") ?? .gemini20FlashLite
  }

  private func loadSelectedSummaryStyle() -> SummaryStyle {
    let raw = UserDefaults(suiteName: AppConstants.AppGroups.identifier)?.string(
      forKey: SettingsService.summaryStyleKey)
    return SummaryStyle(rawValue: raw ?? "default") ?? .default
  }

  private func loadSelectedSummaryLength() -> SummaryLength {
    let raw = userDefaults.string(forKey: Keys.summaryLength)
    return SummaryLength(rawValue: raw ?? "medium") ?? .medium
  }

  private func loadModelSelectionMode() -> ModelSelectionMode {
    let raw = userDefaults.string(forKey: SettingsService.modelSelectionModeKey)
    return ModelSelectionMode(rawValue: raw ?? ModelSelectionMode.smart.rawValue) ?? .smart
  }

  private func loadLanguageSelectionMode() -> LanguageSelectionMode {
    let raw = userDefaults.string(forKey: SettingsService.languageSelectionModeKey)
    return LanguageSelectionMode(rawValue: raw ?? LanguageSelectionMode.auto.rawValue) ?? .auto
  }

  private func loadAIBackendMode() -> AIBackendMode {
    let raw = userDefaults.string(forKey: SettingsService.aiBackendModeKey)
    return AIBackendMode(rawValue: raw ?? AIBackendMode.managedFirebase.rawValue)
      ?? .managedFirebase
  }

  private static func defaultLanguageCode() -> String {
    Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "en"
  }
}

extension Notification.Name {
  static let summaryLanguageChanged = Notification.Name("summaryLanguageChanged")
}
