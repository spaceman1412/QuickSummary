import Testing

@testable import QuickSummaryShared

@MainActor
struct QuickSummarySharedTests {
    @Test func languageMode_auto_setsSummaryLanguageAuto() async throws {
        let settings = SettingsService.shared
        // Ensure a clean start
        settings.languageSelectionMode = .manual
        settings.summaryLanguage = "en"

        settings.languageSelectionMode = .auto
        #expect(settings.summaryLanguage == "auto")
    }

    @Test func languageMode_manual_setsDeviceDefault() async throws {
        let settings = SettingsService.shared
        settings.languageSelectionMode = .auto
        settings.summaryLanguage = "auto"

        settings.languageSelectionMode = .manual
        let deviceDefault = Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "en"
        #expect(settings.summaryLanguage == deviceDefault)
    }

    @Test func modelSelectionMode_persistsAndUpdates() async throws {
        let settings = SettingsService.shared
        settings.modelSelectionMode = .manual
        #expect(settings.modelSelectionMode == .manual)
        settings.modelSelectionMode = .smart
        #expect(settings.modelSelectionMode == .smart)
    }

    @Test func aiModel_updatesInManualMode() async throws {
        let settings = SettingsService.shared
        settings.modelSelectionMode = .manual
        let original = settings.selectedAIModel
        let newModel: AIModel =
            (original == .gemini20FlashLite) ? .gemini20Flash : .gemini20FlashLite
        settings.selectedAIModel = newModel
        #expect(settings.selectedAIModel == newModel)
    }
}
