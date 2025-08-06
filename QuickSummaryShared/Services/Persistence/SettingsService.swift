import Foundation

public class SettingsService: ObservableObject {
  public static let shared = SettingsService()

  private static let aiModelKey = "selectedAIModel"
  private static let summaryStyleKey = "selectedSummaryStyle"
  private static let summaryLengthKey = "selectedSummaryLength"

  private let userDefaults: UserDefaults

  // Keys for UserDefaults
  private enum Keys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let summaryLanguage = "summaryLanguage"
    static let summaryLength = "selectedSummaryLength"
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
    self.selectedSummaryStyle = .default
    self.selectedSummaryLength = .medium

    // Load saved values
    self.summaryLanguage = loadSummaryLanguage()
    self.selectedAIModel = loadSelectedAIModel()
    self.selectedSummaryStyle = loadSelectedSummaryStyle()
    self.selectedSummaryLength = loadSelectedSummaryLength()
  }

  // MARK: - Methods
  public func refreshSettings() {
    summaryLanguage = loadSummaryLanguage()
    selectedAIModel = loadSelectedAIModel()
    selectedSummaryStyle = loadSelectedSummaryStyle()
    selectedSummaryLength = loadSelectedSummaryLength()
  }

  public func markOnboardingCompleted() {
    hasCompletedOnboarding = true
  }

  private func resetToDefaults() {
    summaryLanguage = SettingsService.defaultLanguageCode()
    selectedAIModel = .gemini20FlashLite
    selectedSummaryStyle = .default
    selectedSummaryLength = .medium
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

  private static func defaultLanguageCode() -> String {
    Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "en"
  }
}

extension Notification.Name {
  static let summaryLanguageChanged = Notification.Name("summaryLanguageChanged")
}
