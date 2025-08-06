import QuickSummaryShared
import SwiftData
import SwiftUI

struct HistoryView: View {
  @StateObject private var viewModel = HistoryViewModel()
  @Environment(\.modelContext) private var modelContext
  @Query private var summaries: [SummaryItem]

  init() {
    // Initialize with empty query, will be updated based on search
    _summaries = Query(sort: \SummaryItem.createdAt, order: .reverse)
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        summaryList
      }
      .navigationTitle("History")
      .searchable(text: $viewModel.searchText, prompt: "Search summaries...")
    }
    .onAppear {
      print("[QuickSummary] All summaries loaded in main app: \(summaries)")
    }
  }

  private var summaryList: some View {
    Group {
      if filteredSummaries.isEmpty {
        emptyState
      } else {
        List {
          ForEach(filteredSummaries) { summary in
            NavigationLink(destination: SummaryDetailView(summary: summary)) {
              SummaryRowView(summary: summary, viewModel: viewModel)
            }
          }
          .onDelete(perform: deleteSummaries)
        }
      }
    }
  }

  private var filteredSummaries: [SummaryItem] {
    if viewModel.searchText.isEmpty {
      return summaries
    } else {
      return summaries.filter { summary in
        summary.originalText.localizedCaseInsensitiveContains(viewModel.searchText)
          || summary.summaryText.localizedCaseInsensitiveContains(viewModel.searchText)
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "doc.text.magnifyingglass")
        .font(.system(size: 60))
        .foregroundColor(.gray)

      Text(viewModel.searchText.isEmpty ? "No summaries yet" : "No matching summaries")
        .font(.headline)
        .foregroundColor(.secondary)

      Text(
        viewModel.searchText.isEmpty
          ? "Create your first summary to see it here"
          : "Try adjusting your search terms"
      )
      .font(.subheadline)
      .foregroundColor(.secondary)
      .multilineTextAlignment(.center)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func deleteSummaries(offsets: IndexSet) {
    withAnimation {
      for index in offsets {
        let summary = filteredSummaries[index]
        viewModel.deleteSummary(summary, context: modelContext)
      }
    }
  }
}

struct SummaryRowView: View {
  let summary: SummaryItem
  let viewModel: HistoryViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        if let title = summary.title, !title.isEmpty {
          Text(title)
            .font(.headline)
            .foregroundColor(.primary)
			.lineLimit(1)
          Spacer()
        } else {
          Text(viewModel.originalTextPreview(summary.originalText))
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(1)
          Spacer()
        }
        Text(viewModel.formattedDate(summary.createdAt))
          .font(.caption)
          .foregroundColor(.secondary)
      }
      if let title = summary.title, !title.isEmpty {
        Text(viewModel.originalTextPreview(summary.originalText))
          .font(.subheadline)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
      Text(viewModel.summaryPreview(summary.summaryText))
        .font(.body)
        .lineLimit(2)
      HStack {
        Label(
          "\(TimeSavingCalculator.formatTime(minutes: summary.minutesSaved)) saved",
          systemImage: "clock.fill"
        )
        .font(.caption)
        .foregroundColor(.green)
        Spacer()
        if !summary.chatMessages.isEmpty {
          Label("\(summary.chatMessages.count)", systemImage: "bubble.left.and.bubble.right")
            .font(.caption)
            .foregroundColor(.blue)
        }
      }
    }
    .padding(.vertical, 4)
  }
}

#Preview {
  HistoryView()
    .modelContainer(for: SummaryItem.self, inMemory: true)
}
