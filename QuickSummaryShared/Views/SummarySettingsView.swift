import SwiftUI

struct SummarySettingsView: View {
    @ObservedObject var settingsService = SettingsService.shared
    @Environment(\.dismiss) var dismiss
    @State private var languageSheetPresented = false
    @State private var languageSearchText = ""

    private var supportedLanguages: [(code: String, name: String)] {
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

    private var filteredLanguages: [(code: String, name: String)] {
        if languageSearchText.isEmpty {
            return supportedLanguages
        } else {
            return supportedLanguages.filter {
                $0.name.localizedCaseInsensitiveContains(languageSearchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Model Selection")) {
                    Picker("Mode", selection: $settingsService.modelSelectionMode) {
                        ForEach(ModelSelectionMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if settingsService.modelSelectionMode == .manual {
                    Section(header: Text("AI Model")) {
                        Picker("Select Model", selection: $settingsService.selectedAIModel) {
                            ForEach(AIModel.allCases) { model in
                                Text(model.title).tag(model)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }

                Section(header: Text("Summary Style")) {
                    Picker("Select Style", selection: $settingsService.selectedSummaryStyle) {
                        ForEach(SummaryStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section(header: Text("Summary Length")) {
                    Picker("Select Length", selection: $settingsService.selectedSummaryLength) {
                        ForEach(SummaryLength.allCases) { length in
                            Text(length.title).tag(length)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Language")) {
                    Button(action: {
                        languageSheetPresented = true
                    }) {
                        HStack {
                            Text("Select Language")
                            Spacer()
                            if let languageName = supportedLanguages.first(where: {
                                $0.code == settingsService.summaryLanguage
                            })?.name {
                                Text(languageName)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
            .sheet(isPresented: $languageSheetPresented) {
                languageSelectionSheet
            }
        }
    }

    private var languageSelectionSheet: some View {
        NavigationView {
            VStack {
                SearchBar(text: $languageSearchText, placeholder: "Search languages")
                    .padding(.horizontal)
                List(filteredLanguages, id: \.code) { lang in
                    Button(action: {
                        settingsService.summaryLanguage = lang.code
                        languageSheetPresented = false
                    }) {
                        HStack {
                            Text(lang.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if settingsService.summaryLanguage == lang.code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Language")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    languageSheetPresented = false
                })
        }
    }
}

private struct SearchBar: View {
    @Binding var text: String
    var placeholder: String

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
