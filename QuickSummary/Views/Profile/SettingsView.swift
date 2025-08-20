import QuickSummaryShared
import SwiftUI

struct SettingsView: View {
  @StateObject private var viewModel = SettingsViewModel()

  var body: some View {
    NavigationStack {
		List {
        // AI Backend selection section
        aiBackendSection

        // AI Model selection section
        aiModelSection

        // Summary Configuration section (combines style and length)
        summaryConfigurationSection

        // Language selection section
        languageSection

        // Usage statistics section
        usageStatsSection

        // Support & Feedback section
        supportSection

        // About section
        aboutSection

      }
      .navigationTitle("Settings")
      .fullScreenCover(isPresented: $viewModel.showOnboarding) {
        OnboardingView(hasCompletedOnboarding: $viewModel.showOnboarding)
      }
    }
  }

  private var aiBackendSection: some View {
    Section("AI Backend") {
      Picker("Backend", selection: $viewModel.settingsService.aiBackendMode) {
        ForEach(AIBackendMode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }
      .pickerStyle(SegmentedPickerStyle())

      if viewModel.settingsService.aiBackendMode == .customAPI {
        VStack(alignment: .leading, spacing: 12) {
          SecureField("Enter your Gemini API key", text: $viewModel.customAPIKey)
            .textFieldStyle(.roundedBorder)
            .onSubmit {
              if !viewModel.customAPIKey.isEmpty {
                viewModel.saveAPIKey()
              }
            }

          HStack {
            Button("Save Key") {
              hideKeyboard()
              viewModel.saveAPIKey()
            }
            .disabled(viewModel.customAPIKey.isEmpty)

            Spacer()

            if viewModel.hasStoredAPIKey {
              Button("Clear Key") {
                viewModel.clearAPIKey()
              }
              .foregroundColor(.red)
            }
          }

          if let keyStatus = viewModel.apiKeyStatus {
            Label(keyStatus, systemImage: viewModel.apiKeyStatusIcon)
              .font(.caption)
              .foregroundColor(viewModel.apiKeyStatusColor)
          }

          Text(
            "Get your free API key from [Google AI Studio](https://aistudio.google.com/app/apikey)"
          )
          .font(.caption)
          .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
      } else {
        Text("Uses Firebase AI SDK (default)")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }

  private var aiModelSection: some View {
    Section("AI Model") {
      // Selection mode
      Picker("Mode", selection: $viewModel.settingsService.modelSelectionMode) {
        ForEach(ModelSelectionMode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }
      .pickerStyle(SegmentedPickerStyle())

      if viewModel.settingsService.modelSelectionMode == .manual {
        Picker("AI Model", selection: $viewModel.settingsService.selectedAIModel) {
          ForEach(AIModel.allCases) { model in
            Text(model.title).tag(model)
          }
        }
        .pickerStyle(MenuPickerStyle())
        Text(viewModel.settingsService.selectedAIModel.description)
          .font(.caption)
          .foregroundColor(.secondary)
      } else {
        Text(
          "Smart Default chooses among fast, cost‑efficient models based on your content and summary length."
        )
        .font(.caption)
        .foregroundColor(.secondary)
      }
    }
  }

  private var summaryConfigurationSection: some View {
    Section("Summary Configuration") {
      // Summary Style
      VStack(alignment: .leading, spacing: 8) {
        Picker("Summary Style", selection: $viewModel.settingsService.selectedSummaryStyle) {
          ForEach(SummaryStyle.allCases) { style in
            Text(style.title).tag(style)
          }
        }
        .pickerStyle(MenuPickerStyle())

        Text(viewModel.settingsService.selectedSummaryStyle.description)
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding(.vertical, 4)

      // Summary Length
      VStack(alignment: .leading, spacing: 8) {
        Picker("Summary Length", selection: $viewModel.settingsService.selectedSummaryLength) {
          ForEach(SummaryLength.allCases) { length in
            Text(length.title).tag(length)
          }
        }
        .pickerStyle(SegmentedPickerStyle())
      }
      .padding(.vertical, 4)
    }
  }

  private var languageSection: some View {
    Section("Summary Language") {
      Picker("Mode", selection: $viewModel.settingsService.languageSelectionMode) {
        ForEach(LanguageSelectionMode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }
      .pickerStyle(SegmentedPickerStyle())
      .onChange(of: viewModel.settingsService.languageSelectionMode) { _, newValue in
        if newValue == .auto { viewModel.settingsService.summaryLanguage = "auto" }
      }

      if viewModel.settingsService.languageSelectionMode == .manual {
        Button {
          viewModel.languageSheetPresented = true
        } label: {
          HStack {
            Text("Summary Language")
            Spacer()
            if let selected = viewModel.supportedLanguages.first(where: {
              $0.code == viewModel.settingsService.summaryLanguage
            }) {
              Text(selected.name)
                .foregroundColor(.blue)
            } else {
              Text("Select")
                .foregroundColor(.secondary)
            }
            Image(systemName: "chevron.right")
              .foregroundColor(.secondary)
          }
        }
        .sheet(isPresented: $viewModel.languageSheetPresented) {
          NavigationStack {
            VStack {
              SearchBar(text: $viewModel.languageSearchText, placeholder: "Search languages")
                .padding(.horizontal)
              List {
                ForEach(viewModel.filteredLanguages, id: \.code) { lang in
                  Button {
                    viewModel.settingsService.summaryLanguage = lang.code
                    viewModel.languageSheetPresented = false
                  } label: {
                    HStack {
                      Text(lang.name)
                      if lang.code == viewModel.settingsService.summaryLanguage {
                        Spacer()
                        Image(systemName: "checkmark")
                          .foregroundColor(.accentColor)
                      }
                    }
                  }
                }
              }
            }
            .navigationTitle("Select Language")
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { viewModel.languageSheetPresented = false }
              }
            }
          }
        }
      } else {
        Text("Auto Detect (matches input/question language; chat always mirrors the question)")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }

  private var usageStatsSection: some View {
    Section("Usage Statistics") {
      HStack {
        Label("Time Saved", systemImage: "clock.fill")
        Spacer()
        Text(viewModel.usageTracker.formattedMinutesSaved)
          .foregroundColor(.green)
          .fontWeight(.medium)
      }

      HStack {
        Label("Summaries Created", systemImage: "doc.text")
        Spacer()
        Text("\(viewModel.usageTracker.totalSummariesCreated)")
          .foregroundColor(.blue)
          .fontWeight(.medium)
      }

      HStack {
        Label("API Calls", systemImage: "network")
        Spacer()
        Text("\(viewModel.usageTracker.totalAPICallsCount)")
          .foregroundColor(.purple)
          .fontWeight(.medium)
      }
    }
  }

  // MARK: - About Section

  private var aboutSection: some View {
    Section("About") {
      HStack {
        Label {
          Text("Version")
        } icon: {
          Image(systemName: "info.circle")
        }
        Spacer()
        Text(Bundle.main.appVersion ?? "N/A")
          .foregroundColor(.secondary)
      }

      Button {
        viewModel.showOnboarding = true
      } label: {
        HStack {
          Label {
            Text("View Tutorial")
          } icon: {
            Image(systemName: "play.circle")
              .foregroundColor(.blue)
          }
          Spacer()
          Image(systemName: "chevron.right")
            .foregroundColor(.secondary)
        }
      }
      .foregroundColor(.primary)

      VStack(alignment: .leading, spacing: 4) {
        Label {
          Text("Privacy")
        } icon: {
          Image(systemName: "lock.shield")
        }
        Text(
          "All data is stored locally on your device. No personal information is sent to external services except for AI processing."
        )
        .font(.caption)
        .foregroundColor(.secondary)
      }
      .padding(.vertical, 4)
    }
  }

  // MARK: - Support & Feedback Section

  private var supportSection: some View {
    Section("Support & Feedback") {
      VStack(alignment: .leading, spacing: 8) {
        Text("This project is open-source and community-driven. Your feedback is welcome!")
          .font(.caption)
          .foregroundColor(.secondary)

        Link(destination: URL(string: "https://github.com/spaceman1412/QuickSummary")!) {
          HStack {
            Label("Report an Issue on GitHub", systemImage: "ladybug.fill")
            Spacer()
            Image(systemName: "arrow.up.right.square")
              .foregroundColor(.secondary)
          }
        }
        .foregroundColor(.primary)
      }
      .padding(.vertical, 4)
    }
  }
}

#Preview {
  SettingsView()
}

// Add a simple SearchBar view for use in the sheet
struct SearchBar: View {
  @Binding var text: String
  var placeholder: String = "Search"
  var body: some View {
    HStack {
      Image(systemName: "magnifyingglass")
        .foregroundColor(.secondary)
      TextField(placeholder, text: $text)
        .autocorrectionDisabled(true)
        .textInputAutocapitalization(.never)
    }
    .padding(8)
    .background(Color(.systemGray6))
    .cornerRadius(10)
  }
}
