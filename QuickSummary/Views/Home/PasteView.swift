import QuickSummaryShared
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PasteView: View {
  @StateObject private var viewModel = PasteViewModel()
  @Environment(\.modelContext) private var modelContext
  @State private var showSummaryScreen = false
  @State private var extractedText: String?
  @State private var fetchedTitle: String?
  @State private var isLoading = false
  @State private var showError = false
  @State private var errorMessage = ""
  @State private var isShowingDocumentPicker = false
  @State private var animatedCircle = false
  @State private var detectedType: InputType?
  @State private var summaryViewModel: SummaryViewModel?

  func readTextFromClipboard() -> String? {
    // Get a reference to the general pasteboard
    let pasteboard = UIPasteboard.general

    // Check if the pasteboard contains a string and retrieve it.
    // The 'string' property is a convenience for getting plain text.
    if let content = pasteboard.string,
      !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      return content
    } else {
      return nil
    }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        LinearGradient(
          gradient: Gradient(colors: [
            Color(.systemBlue).opacity(0.12),
            Color(.systemBackground),
          ]),
          startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()

        VStack(spacing: 30) {
          headerSection

          Button {
            if let clipboardText = readTextFromClipboard() {
              handlePaste(text: clipboardText)
            } else {
              errorMessage = "Clipboard is empty or not text."
              showError = true
            }
          } label: {
            HStack {
              Image(systemName: "doc.on.clipboard")
              Text("Paste from Clipboard")
            }
            .foregroundColor(.white)
            .padding(8)
            .background(Color.blue)
            .cornerRadius(8)
          }
          .padding(.horizontal)

          Button {
            isShowingDocumentPicker = true
          } label: {
            HStack {
              Image(systemName: "doc.fill")
              Text("Choose PDF File")
            }
            .foregroundColor(.white)
            .padding(8)
            .background(Color.blue)
            .cornerRadius(8)
          }
          .padding(.horizontal)
          .fileImporter(
            isPresented: $isShowingDocumentPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
          ) { result in
            switch result {
            case .success(let urls):
              if let url = urls.first {
                handlePDF(url: url)
              }
            case .failure(let error):
              errorMessage =
                "Failed to import file: \(error.localizedDescription)"
              showError = true
            }
          }

          if isLoading {
            loadingSection
          }

          Spacer()
        }
        .padding()
      }
      .navigationTitle("QuickSummary")
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(isPresented: $showSummaryScreen) {
        if let viewModel = summaryViewModel {
          SummaryView(
            viewModel: viewModel,
            onSave: {
              showSummaryScreen = false
              summaryViewModel = nil
            },
            onCancel: {
              showSummaryScreen = false
              summaryViewModel = nil
            },
            modelContext: modelContext
          )
        }
      }
      .alert("Paste Failed", isPresented: $showError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(errorMessage)
      }
    }
  }

  private func handlePaste(text: String) {
    isLoading = true
    Task {
      do {
        // Fetch title if content is URL or YouTube
        if getInputType(text) == .url || getInputType(text) == .youtube {
          fetchedTitle = await fetchURLTitle(from: text)
        }

        let summaryText = try await SummaryGenerator.processInput(input: text)
        detectedType = getInputType(text)
        extractedText = summaryText
        // Initialize a stable SummaryViewModel instance before navigating
        if summaryViewModel == nil, let type = detectedType, let preparedText = extractedText {
          summaryViewModel = SummaryViewModel(
            initialText: preparedText, initialTitle: fetchedTitle, inputType: type)
        }
        isLoading = false
        showSummaryScreen = true
      } catch {
        errorMessage = "Failed to generate summary: \(error.localizedDescription)"
        showError = true
        isLoading = false
      }
    }
  }

  private var headerSection: some View {
    VStack(spacing: 14) {
      Image(systemName: "doc.text.magnifyingglass")
        .font(.system(size: 48))
        .foregroundColor(.blue)
        .padding(.top, 8)
      Text("Paste and summarize any text or URL in one tap.")
        .font(.headline)
        .multilineTextAlignment(.center)
        .foregroundColor(.primary)
    }
    .padding(.vertical, 28)
    .padding(.horizontal, 18)
    .background(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(Color(.systemBackground).opacity(0.85))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 2)
    )
    .padding(.top, 32)
    .padding(.horizontal, 8)
  }

  private var loadingSection: some View {
    VStack(spacing: 16) {
      // Animated loading indicator
      ZStack {
        Circle()
          .stroke(Color.blue.opacity(0.2), lineWidth: 4)
          .frame(width: 30, height: 30)

        Circle()
          .trim(from: 0, to: 0.7)
          .stroke(
            LinearGradient(
              colors: [.blue, .purple],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            style: StrokeStyle(lineWidth: 4, lineCap: .round)
          )
          .frame(width: 30, height: 30)
          .rotationEffect(.degrees(animatedCircle ? 360 : 0))
          .onAppear {
            if isLoading {
              withAnimation(
                .easeInOut(duration: 1).repeatForever(
                  autoreverses: false)
              ) {
                animatedCircle.toggle()
              }
            }
          }
      }

      VStack(spacing: 8) {
        Text("Generating Summary")
          .font(.headline)
          .fontWeight(.semibold)
        Text("Please wait while we analyze your content...")
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .padding(.top, 32)
  }

  private func handlePDF(url: URL) {
    isLoading = true
    Task {
      do {
        // Start accessing security-scoped resource for file imported via fileImporter
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
          if accessing {
            url.stopAccessingSecurityScopedResource()
          }
        }

        let extracted = try await DocumentParserService.extractText(
          from: url)
        detectedType = .pdf
        extractedText = extracted
        isLoading = false
        showSummaryScreen = true
      } catch {
        errorMessage =
          "Failed to read PDF: \(error.localizedDescription)"
        showError = true
        isLoading = false
      }
    }
  }
}

#Preview {
  PasteView()
    .modelContainer(for: SummaryItem.self, inMemory: true)
}
