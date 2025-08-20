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

    // MARK: - AI Backend Mode Tests

    @Test func aiBackendMode_defaultsToManagedFirebase() async throws {
        let settings = SettingsService.shared

        // Clear any existing backend mode setting to test true default
        if let userDefaults = UserDefaults(suiteName: AppConstants.AppGroups.identifier) {
            userDefaults.removeObject(forKey: "aiBackendMode")
        }

        // Refresh settings to load from UserDefaults (should get default)
        settings.refreshSettings()

        // Should default to managedFirebase when no value is stored
        #expect(settings.aiBackendMode == .managedFirebase)
    }

    @Test func aiBackendMode_persistsAndUpdates() async throws {
        let settings = SettingsService.shared
        settings.aiBackendMode = .customAPI
        #expect(settings.aiBackendMode == .customAPI)
        settings.aiBackendMode = .managedFirebase
        #expect(settings.aiBackendMode == .managedFirebase)
    }

    @Test func aiBackendMode_persistsAcrossRefresh() async throws {
        let settings = SettingsService.shared
        settings.aiBackendMode = .customAPI
        #expect(settings.aiBackendMode == .customAPI)

        settings.refreshSettings()
        #expect(settings.aiBackendMode == .customAPI)
    }

    // MARK: - KeychainService Tests

    @Test func keychainService_saveAndRetrieveAPIKey() async throws {
        let keychain = KeychainService.shared
        let testKey = "dumbkey"

        // Clean up any existing key first
        try? keychain.deleteAPIKey()

        // Save key
        try keychain.saveAPIKey(testKey)

        // Retrieve key
        let retrievedKey = try keychain.getAPIKey()
        #expect(retrievedKey == testKey)

        // Clean up
        try keychain.deleteAPIKey()
    }

    @Test func keychainService_deleteAPIKey() async throws {
        let keychain = KeychainService.shared
        let testKey = "AIzaSyTestKey456"

        // Save key first
        try keychain.saveAPIKey(testKey)
        #expect(keychain.hasAPIKey() == true)

        // Delete key
        try keychain.deleteAPIKey()
        #expect(keychain.hasAPIKey() == false)

        // Try to retrieve - should return nil
        let retrievedKey = try keychain.getAPIKey()
        #expect(retrievedKey == nil)
    }

    @Test func keychainService_hasAPIKey() async throws {
        let keychain = KeychainService.shared
        let testKey = "AIzaSyTestKey789"

        // Clean up first
        try? keychain.deleteAPIKey()
        #expect(keychain.hasAPIKey() == false)

        // Save key
        try keychain.saveAPIKey(testKey)
        #expect(keychain.hasAPIKey() == true)

        // Clean up
        try keychain.deleteAPIKey()
        #expect(keychain.hasAPIKey() == false)
    }

    @Test func keychainService_invalidInput() async throws {
        let keychain = KeychainService.shared

        // Try to save empty key - should throw
        #expect(throws: KeychainError.self) {
            try keychain.saveAPIKey("")
        }
    }

    // MARK: - GeminiAPIClient Tests (with mocked data)

    @Test func geminiAPIClient_missingAPIKey_throwsError() async throws {
        let client = GeminiAPIClient.shared

        // Ensure no API key is stored
        try? KeychainService.shared.deleteAPIKey()

        // Try to generate content - should throw missing API key error
        await #expect(throws: GeminiAPIError.self) {
            _ = try await client.generateContent(modelKey: "gemini-2.0-flash-001", prompt: "Test")
        }
    }

    // Note: We can't easily test actual API calls without mocking URLSession,
    // but we can test the error handling paths and ensure the client is properly initialized
    @Test func geminiAPIClient_initialization() async throws {
        let client = GeminiAPIClient.shared
        // Should not be nil
        #expect(client != nil)
    }

    // MARK: - GeminiAPIClient Stream Tests

    @Test func geminiAPIClient_generateContentStream_missingAPIKey_throwsError() async throws {
        let client = GeminiAPIClient.shared

        // Ensure no API key is stored
        try? KeychainService.shared.deleteAPIKey()

        // Try to generate content stream - should throw missing API key error
        let stream = client.generateContentStream(modelKey: "gemini-2.0-flash-001", prompt: "Test")

        do {
            for try await _ in stream {
                // Should not get here
                #expect(Bool(false), "Expected error but got stream data")
            }
        } catch let error as GeminiAPIError {
            switch error {
            case .missingAPIKey:
                break  // Expected error
            default:
                #expect(Bool(false), "Expected .missingAPIKey but got \(error)")
            }
        } catch {
            #expect(Bool(false), "Expected GeminiAPIError.missingAPIKey but got \(error)")
        }
    }

    @Test func geminiAPIClient_generateContentStream_withValidKey_createsStream() async throws {
        let client = GeminiAPIClient.shared
        let testKey = "AIzaSyTestStreamKey123"

        // Save a test key
        try KeychainService.shared.saveAPIKey(testKey)

        // Create stream - should not throw immediately
        let stream = client.generateContentStream(modelKey: "gemini-2.0-flash-001", prompt: "Hi")

        // Verify stream was created (we can't test actual network without mocking)
        #expect(stream != nil)

        // Clean up
        try KeychainService.shared.deleteAPIKey()
    }

    @Test func geminiAPIClient_generateContentStream_emptyPrompt_stillCreatesStream() async throws {
        let client = GeminiAPIClient.shared
        let testKey = "AIzaSyTestStreamKey456"

        // Save a test key
        try KeychainService.shared.saveAPIKey(testKey)

        // Create stream with empty prompt - should still create stream
        let stream = client.generateContentStream(modelKey: "gemini-2.0-flash-001", prompt: "")

        // Verify stream was created
        #expect(stream != nil)

        // Clean up
        try KeychainService.shared.deleteAPIKey()
    }

    @Test func geminiAPIClient_generateContentStream_invalidModelKey_stillCreatesStream()
        async throws
    {
        let client = GeminiAPIClient.shared
        let testKey = "AIzaSyTestStreamKey789"

        // Save a test key
        try KeychainService.shared.saveAPIKey(testKey)

        // Create stream with invalid model - should create stream (API will handle error)
        let stream = client.generateContentStream(modelKey: "invalid-model", prompt: "Test")

        // Verify stream was created (validation happens during network call)
        #expect(stream != nil)

        // Clean up
        try KeychainService.shared.deleteAPIKey()
    }

    // MARK: - Mock URL Session Tests (More comprehensive testing would require URLProtocol mocking)

    @Test func geminiAPIClient_streamCreation_parameters() async throws {
        let client = GeminiAPIClient.shared
        let testKey = "AIzaSyTestStreamParams"

        try KeychainService.shared.saveAPIKey(testKey)

        let testCases = [
            ("gemini-2.0-flash-001", "Hello world"),
            ("gemini-2.5-flash", "Test prompt"),
            ("gemini-2.0-flash-lite-001", ""),
            ("gemini-2.5-pro", "Multi\nline\nprompt"),
        ]

        for (model, prompt) in testCases {
            let stream = client.generateContentStream(modelKey: model, prompt: prompt)
            #expect(stream != nil, "Stream should be created for model: \(model)")
        }

        try KeychainService.shared.deleteAPIKey()
    }

    @Test func geminiAPIClient_concurrentStreamCreation() async throws {
        let client = GeminiAPIClient.shared
        let testKey = "AIzaSyConcurrentTest"

        try KeychainService.shared.saveAPIKey(testKey)

        // Create multiple streams concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask { @MainActor in
                    let stream = client.generateContentStream(
                        modelKey: "gemini-2.0-flash-001",
                        prompt: "Concurrent test \(i)"
                    )
                    #expect(stream != nil)
                }
            }
        }

        try KeychainService.shared.deleteAPIKey()
    }
}
