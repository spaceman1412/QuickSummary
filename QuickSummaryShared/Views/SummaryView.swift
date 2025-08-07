import MarkdownUI
import SwiftData
import SwiftUI

private struct BlinkingCursorView: View {
	@State private var isVisible = true
	var body: some View {
		RoundedRectangle(cornerRadius: 2)
			.frame(width: 8, height: 22)
			.opacity(isVisible ? 1 : 0)
			.background(
				RoundedRectangle(cornerRadius: 2)
					.fill(Color(.systemBackground))
			)
			.onAppear {
				withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: false)) {
					isVisible.toggle()
				}
			}
	}
}

public struct SummaryView: View {
	@ObservedObject var viewModel: SummaryViewModel
	let modelContext: ModelContext

	let onSave: () -> Void
	let onCancel: () -> Void
	enum Mode: String, CaseIterable, Identifiable {
		case summary = "Summary"
		case chat = "Chat"
		var id: String { rawValue }
	}
	@State private var selectedMode: Mode = .summary
	@State private var isShowError: Bool = false

	public init(
		viewModel: SummaryViewModel,
		onSave: @escaping () -> Void,
		onCancel: @escaping () -> Void,
		modelContext: ModelContext
	) {
		self.viewModel = viewModel
		self.onSave = onSave
		self.onCancel = onCancel
		self.modelContext = modelContext
	}

	public var body: some View {
		VStack(spacing: 20) {
			compactHeader

			if isShowError {
				VStack {
					Text("Please try again or switch to different model to avoid overload")
						.font(.title2)
						.bold()
				}.frame(
					maxWidth: .infinity, maxHeight: .infinity,
					alignment: .topLeading)
			} else {
				if selectedMode == .summary {
					VStack {
						summarySection
					}

				} else {
					chatSection
						.padding(.bottom, 12)
				}
			}
		}
		.padding(.horizontal, 8)
		.navigationBarBackButtonHidden(true)
		.contentShape(Rectangle())
		.onTapGesture {
			hideKeyboard()
		}
		.task {
			do {
				try await viewModel.processSummary()
			} catch {
				isShowError = true
			}
		}
	}

	private func handleSave() {
		viewModel.saveToHistory(modelContext: modelContext)
		onSave()
	}

	private var compactHeader: some View {
		HStack(spacing: 8) {
			Button(action: onCancel) {
				Text("Cancel")
					.padding(8)
			}
			Spacer(minLength: 0)
			Picker("Mode", selection: $selectedMode) {
				Image(systemName: "doc.text").tag(Mode.summary)
				Image(systemName: "bubble.left.and.bubble.right").tag(Mode.chat)
			}
			.pickerStyle(.segmented)
			.frame(maxWidth: 120)
			Spacer(minLength: 0)

			HStack {
				Button(action: {
					Task {
						do {
							try await viewModel.retrySummary()
						} catch {
							isShowError = true
						}
					}
				}) {
					Image(systemName: "arrow.clockwise")
				}

				Button(action: {
					viewModel.isShowingSettings = true
				}) {
					Image(systemName: "gear")
				}
			}

			Button(action: handleSave) {
				Text("Save")
					.padding(8)
			}
			.disabled((viewModel.summaryResult != nil) ? false : true)
		}
		.padding(.vertical, 4)
		.padding(.horizontal, 4)
	}

	private var summarySection: some View {
		ScrollView {
			VStack(alignment: .leading) {
				if let title = viewModel.initialTitle {
					Text(title)
						.font(.title2)
						.bold()
						.padding(.bottom, 8)
						.textSelection(.enabled)
				}
				HStack(alignment: .bottom, spacing: 0) {
					Markdown(viewModel.streamingSummaryText)
						.font(.body)
						.textSelection(.enabled)
						.fixedSize(horizontal: false, vertical: true)
					if viewModel.isLoadingSummary && viewModel.streamingSummaryText.isEmpty {
						BlinkingCursorView()
							.padding(.leading, 2)
					}
				}
				Color.clear.frame(height: 50)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.sheet(isPresented: $viewModel.isShowingSettings) {
			SummarySettingsView()
		}
		.padding(.vertical, 8)
		.scrollIndicators(.hidden)
	}

	private var chatSection: some View {
		VStack(spacing: 0) {
			ScrollViewReader { proxy in
				ScrollView {
					VStack(alignment: .leading, spacing: 12) {
						if viewModel.chatMessages.isEmpty {
							suggestedPrompts
						} else {
							ForEach(viewModel.chatMessages, id: \.id) {
								message in
								ChatMessageView(message: message)
									.id(message.id)
							}
						}
					}
					.padding()
				}
				.onChange(of: viewModel.chatMessages.count) {
					if let lastMessage = viewModel.chatMessages.last {
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
				ForEach(viewModel.suggestedPrompts, id: \.self) { prompt in
					Button {
						viewModel.useSuggestedPrompt(prompt)
					} label: {
						Text(prompt)
							.font(.callout)
							.padding(.horizontal, 12)
							.padding(.vertical, 8)
							.background(Color.accentColor.opacity(0.1))
							.foregroundColor(.accentColor)
							.clipShape(Capsule())
					}
				}
			}
		}
		.padding(.vertical, 8)
	}

	private var messageInput: some View {
		VStack(spacing: 0) {
			HStack(alignment: .center, spacing: 12) {
				TextField(
					"Ask a question...", text: $viewModel.messageText,
					axis: .vertical
				)
				.padding(.horizontal, 12)
				.padding(.vertical, 10)
				.background(Color(.systemBackground))
				.clipShape(
					RoundedRectangle(cornerRadius: 20, style: .continuous)
				)
				.overlay(
					RoundedRectangle(cornerRadius: 20, style: .continuous)
						.stroke(Color(.systemGray4), lineWidth: 1)
				)
				.shadow(color: Color(.systemGray).opacity(0.3), radius: 4, y: 2)

				Button {
					Task { await viewModel.sendMessage() }
				} label: {
					Group {
						if viewModel.isLoadingChat {
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
											viewModel.messageText.isEmpty
												? Color.gray : Color.accentColor
										)
								)
								.shadow(
									color: .accentColor.opacity(
										viewModel.messageText.isEmpty ? 0 : 0.4),
									radius: 5,
									y: 2
								)
						}
					}.frame(width: 50, height: 50)
				}
				.disabled(
					viewModel.messageText.trimmingCharacters(
						in: .whitespacesAndNewlines
					).isEmpty
						|| viewModel.isLoadingChat
				)
				.animation(
					.spring(response: 0.4, dampingFraction: 0.6),
					value: viewModel.messageText.isEmpty)
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 8)
		}
	}

}

private struct ChatMessageView: View {
	let message: ChatMessage

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

				Text(formattedTime(message.timestamp))
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
			Text(formattedTime(message.timestamp))
				.font(.caption2)
				.foregroundColor(.secondary)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
	}

	private func formattedTime(_ date: Date) -> String {
		let formatter = DateFormatter()
		formatter.timeStyle = .short
		return formatter.string(from: date)
	}
}
