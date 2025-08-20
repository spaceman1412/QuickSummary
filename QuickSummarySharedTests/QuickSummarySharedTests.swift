import Testing

@testable import QuickSummaryShared

@MainActor
struct QuickSummarySharedTests {
    // MARK: - Language Mode Tests

    @Test func languageMode_auto_setsSummaryLanguageAuto() async throws {
        let settings = SettingsService.shared
        // Ensure a clean start
        settings.languageSelectionMode = .manual
        settings.summaryLanguage = "en"

        settings.languageSelectionMode = .auto
        #expect(settings.summaryLanguage == "auto")
    }

    @Test func languageMode_manual_setsDeviceDefault_ifComingFromAuto() async throws {
        let settings = SettingsService.shared
        settings.languageSelectionMode = .auto
        settings.summaryLanguage = "auto"

        settings.languageSelectionMode = .manual
        let deviceDefault = Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "en"
        #expect(settings.summaryLanguage == deviceDefault)
    }

    @Test func languageMode_manual_keepsUserChoice_whenAlreadyManual() async throws {
        let settings = SettingsService.shared
        // Start manual and pick a language
        settings.languageSelectionMode = .manual
        settings.summaryLanguage = "fr"
        #expect(settings.summaryLanguage == "fr")
        // Toggle manual again (no-op) should not override choice
        settings.languageSelectionMode = .manual
        #expect(settings.summaryLanguage == "fr")
    }

    @Test func language_manualSelection_updatesToChosenCode() async throws {
        let settings = SettingsService.shared
        settings.languageSelectionMode = .manual
        let chosen = "es"
        settings.summaryLanguage = chosen
        #expect(settings.summaryLanguage == chosen)
    }

    @Test func language_switch_auto_then_manual_initializesToDeviceDefault_notPreviousChoice()
        async throws
    {
        let settings = SettingsService.shared
        // Choose a manual language first
        settings.languageSelectionMode = .manual
        settings.summaryLanguage = "vi"
        #expect(settings.summaryLanguage == "vi")
        // Switch to auto -> should be sentinel
        settings.languageSelectionMode = .auto
        #expect(settings.summaryLanguage == "auto")
        // Switch back to manual -> initializes to device default per current behavior
        settings.languageSelectionMode = .manual
        let deviceDefault = Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "en"
        #expect(settings.summaryLanguage == deviceDefault)
    }

    // MARK: - AI Model Mode Tests

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

    @Test func aiModel_manualChoice_persistsAcrossModeToggles() async throws {
        let settings = SettingsService.shared
        // Pick a non-default model in manual mode
        settings.modelSelectionMode = .manual
        settings.selectedAIModel = .gemini25FlashLite
        #expect(settings.selectedAIModel == .gemini25FlashLite)
        // Switch to smart
        settings.modelSelectionMode = .smart
        // Model value should remain unchanged in storage
        #expect(settings.selectedAIModel == .gemini25FlashLite)
        // Switch back to manual and ensure the same model is still selected
        settings.modelSelectionMode = .manual
        #expect(settings.selectedAIModel == .gemini25FlashLite)
    }

    // MARK: - Persistence/Refresh

    @Test func refreshSettings_keepsPersistedValues() async throws {
        let settings = SettingsService.shared
        // Set some values
        settings.modelSelectionMode = .manual
        settings.selectedAIModel = .gemini25Flash
        settings.languageSelectionMode = .manual
        settings.summaryLanguage = "de"
        settings.selectedSummaryStyle = .keyPoints
        settings.selectedSummaryLength = .detailed

        // Now refresh from persistence and verify values remain
        settings.refreshSettings()
        #expect(settings.modelSelectionMode == .manual)
        #expect(settings.selectedAIModel == .gemini25Flash)
        #expect(settings.languageSelectionMode == .manual)
        #expect(settings.summaryLanguage == "de")
        #expect(settings.selectedSummaryStyle == .keyPoints)
        #expect(settings.selectedSummaryLength == .detailed)
    }
}
