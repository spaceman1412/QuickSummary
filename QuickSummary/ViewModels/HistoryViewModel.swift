import Foundation
import QuickSummaryShared
import SwiftData
import SwiftUI

@MainActor
class HistoryViewModel: ObservableObject {
  @Published var searchText: String = ""
  @Published var selectedSummary: SummaryItem?

  /// Filters summaries based on search text
  func searchPredicate() -> Predicate<SummaryItem> {
    if searchText.isEmpty {
      return #Predicate<SummaryItem> { _ in true }
    } else {
      return #Predicate<SummaryItem> { summary in
        summary.originalText.localizedStandardContains(searchText)
          || summary.summaryText.localizedStandardContains(searchText)
      }
    }
  }

  /// Deletes a summary item
  func deleteSummary(_ summary: SummaryItem, context: ModelContext) {
    context.delete(summary)
    try? context.save()
  }

  /// Formats the creation date of a summary
  func formattedDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
  }

  /// Gets a preview of the summary text (first 100 characters)
  func summaryPreview(_ text: String) -> String {
    if text.count <= 100 {
      return text
    }
    return String(text.prefix(100)) + "..."
  }

  /// Gets a preview of the original text (first 50 characters)
  func originalTextPreview(_ text: String) -> String {
    if text.count <= 50 {
      return text
    }
    return String(text.prefix(50)) + "..."
  }

  /// Selects a summary for detailed view
  func selectSummary(_ summary: SummaryItem) {
    selectedSummary = summary
  }
}
