import Foundation
import QuickSummaryShared
import SwiftUI

@MainActor
class PasteViewModel: ObservableObject {
  @Published var inputText: String = ""
  @Published var selectedSummaryLength: SummaryLength = .medium

  private let settingsService = SettingsService.shared

  init() {
    // Load user's preferred preset
    self.selectedSummaryLength = settingsService.selectedSummaryLength
  }

  /// Updates the selected preset and saves to settings
  func updateSummaryLength(_ length: SummaryLength) {
    selectedSummaryLength = length
    settingsService.selectedSummaryLength = length
  }

  /// Pastes text from clipboard
  func pasteFromClipboard() {
    #if os(iOS)
      if let clipboardText = UIPasteboard.general.string {
        inputText = clipboardText
      }
    #endif
  }

  /// Clears the input text
  func clearInput() {
    inputText = ""
  }

  /// Checks if input appears to be a URL
  var isInputURL: Bool {
    isValidURL(inputText)
  }

  /// Gets estimated reading time for current input
  var estimatedReadingTime: String? {
    guard !inputText.isEmpty else { return nil }
    return TimeSavingCalculator.estimatedReadingTime(for: inputText)
  }
}
