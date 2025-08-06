import MarkdownUI
import QuickSummaryShared
import SwiftData
import SwiftUI

struct SummaryDetailView: View {
  let summary: SummaryItem
  @StateObject private var summaryDetailViewModel: SummaryDetailViewModel
  @Environment(\.modelContext) private var modelContext

  enum Mode: String, CaseIterable, Identifiable {
    case summary = "Summary"
    case chat = "Chat"
    var id: String { rawValue }
  }
  @State private var selectedMode: Mode = .summary

  init(summary: SummaryItem) {
    self.summary = summary
    self._summaryDetailViewModel = StateObject(
      wrappedValue: SummaryDetailViewModel(summaryItem: summary))
  }

  var body: some View {
    VStack(spacing: 0) {
      // Mode picker header
      modePickerHeader

      if selectedMode == .summary {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            // Summary content
            summaryContent
          }
          .padding()
        }
      } else {
        // Chat section with improved UI
        chatSection
      }
    }
    .contentShape(Rectangle())
    .onTapGesture {
      hideKeyboard()
    }
    .task {
      await summaryDetailViewModel.fetchSuggestedPrompts()
    }
    .onAppear {
      summaryDetailViewModel.syncMessages()
    }
    .onChange(of: selectedMode) { _, newMode in
      if newMode == .chat {
        summaryDetailViewModel.syncMessages()
      }
    }
    .navigationTitle("Summary")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Menu {
          Button {
            shareText(summary.summaryText)
          } label: {
            Label("Share", systemImage: "square.and.arrow.up")
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
    }
    .alert("Error", isPresented: $summaryDetailViewModel.showError) {
      Button("OK") {
        summaryDetailViewModel.clearError()
      }
    } message: {
      Text(summaryDetailViewModel.errorMessage ?? "")
    }
  }

  private var modePickerHeader: some View {
    VStack(spacing: 0) {
      HStack {
        Spacer()
        Picker("Mode", selection: $selectedMode) {
          Image(systemName: "doc.text").tag(Mode.summary)
          Image(systemName: "bubble.left.and.bubble.right").tag(Mode.chat)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 120)
        Spacer()
      }
      .padding(.horizontal)
      .padding(.vertical, 8)

      Divider()
    }
  }

  private var summaryContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Show title if present
      if let title = summary.title, !title.isEmpty {
        Text(title)
          .font(.title2)
          .bold()
          .padding(.bottom, 8)
          .textSelection(.enabled)
      }
      Group {
        if summaryDetailViewModel.isLoading && summary.summaryText.isEmpty {
          VStack(alignment: .center) {
            ProgressView()
              .padding(.bottom, 8)
            Text("Generating Summary...")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity, minHeight: 100)
        } else {
          Markdown(summary.summaryText).font(.body)
            .textSelection(.enabled)
        }
      }
      .padding(.bottom, 8)
    }
  }

  private var chatSection: some View {
    VStack(spacing: 0) {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading, spacing: 12) {
            if summaryDetailViewModel.chatMessages.isEmpty {
              suggestedPrompts
            } else {
              ForEach(summaryDetailViewModel.chatMessages, id: \.id) { message in
                ChatMessageView(message: message, viewModel: summaryDetailViewModel)
                  .id(message.id)
              }
            }
          }
          .padding()
        }
        .onChange(of: summaryDetailViewModel.chatMessages.count) {
          if let lastMessage = summaryDetailViewModel.chatMessages.last {
            withAnimation(.spring()) {
              proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
          }
        }
      }
      .background(Color(uiColor: .systemBackground))

      messageInput
    }
  }

  private var suggestedPrompts: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Try asking:")
        .font(.subheadline)
        .foregroundColor(.secondary)

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 10) {
        ForEach(summaryDetailViewModel.suggestedPrompts, id: \.self) { prompt in
          Button {
            summaryDetailViewModel.useSuggestedPrompt(prompt)
          } label: {
            Text(prompt)
              .font(.callout)
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(Color.accentColor.opacity(0.1))
              .foregroundColor(.accentColor)
              .cornerRadius(12)
          }
        }
      }
    }
    .padding(.vertical, 8)
  }

  private var messageInput: some View {
    VStack(spacing: 0) {
      HStack(alignment: .center, spacing: 12) {
        TextField("Ask a question...", text: $summaryDetailViewModel.messageText, axis: .vertical)
          .padding(.horizontal, 12)
          .padding(.vertical, 10)
          .background(Color(.systemBackground))
          .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
              .stroke(Color(.systemGray4), lineWidth: 1)
          )
          .shadow(color: Color(.systemGray).opacity(0.3), radius: 4, y: 2)

        Button {
          Task {
            await summaryDetailViewModel.sendMessage(modelContext)
          }
        } label: {
          Group {
            if summaryDetailViewModel.isLoading {
              ProgressView()
                .padding(4)
            } else {
              Image(systemName: "arrow.up")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .padding(8)
                .background(
                  Circle()
                    .fill(
                      summaryDetailViewModel.messageText.isEmpty ? Color.gray : Color.accentColor)
                )
                .shadow(
                  color: .accentColor.opacity(summaryDetailViewModel.messageText.isEmpty ? 0 : 0.4),
                  radius: 5,
                  y: 2
                )
            }
          }
          .frame(width: 50, height: 50)
        }
        .disabled(
          summaryDetailViewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || summaryDetailViewModel.isLoading
        )
        .animation(
          .spring(response: 0.4, dampingFraction: 0.6),
          value: summaryDetailViewModel.messageText.isEmpty
        )
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
  }

  private func shareText(_ text: String) {
    let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first
    {
      window.rootViewController?.present(activityVC, animated: true)
    }
  }
}

struct ChatMessageView: View {
  let message: ChatMessage
  let viewModel: SummaryDetailViewModel
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    if message.isFromUser {
      userMessage
    } else {
      aiMessage
    }
  }

  private var userMessage: some View {
    HStack {
      Spacer(minLength: 40)
      VStack(alignment: .trailing, spacing: 4) {
        Text(message.content)
          .textSelection(.enabled)
          .padding(12)
          .background(Color(.systemGray5))
          .foregroundColor(.primary)
          .cornerRadius(16)

        Text(viewModel.formattedTime(message.timestamp))
          .font(.caption2)
          .foregroundColor(.secondary)
      }
    }
  }

  private var aiMessage: some View {
    VStack(alignment: .leading, spacing: 4) {
      Markdown(message.content)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)

      Text(viewModel.formattedTime(message.timestamp))
        .font(.caption2)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

extension DateFormatter {
  static let fullDate: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    formatter.timeStyle = .short
    return formatter
  }()
}

#Preview {
  let summary = SummaryItem(
    originalText: "This is the original text that was summarized.",
    summaryText: "This is the summary of the original text.",
    minutesSaved: 5.0
  )

  return NavigationView {
    SummaryDetailView(summary: summary)
  }
  .modelContainer(for: SummaryItem.self, inMemory: true)
}
