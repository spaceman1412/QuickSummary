import Foundation
import SwiftData

#if canImport(UIKit)
	import UIKit
#endif

public struct SummaryResult {
	let originalText: String
	let summaryText: String
	let minutesSaved: Double
}

@MainActor
public class SummaryViewModel: ObservableObject {
	@Published public var isLoadingSummary: Bool = false
	@Published public var summaryResult: SummaryResult?
	@Published public var chatMessages: [ChatMessage] = []
	@Published public var streamingSummaryText: String = ""
	@Published public var messageText: String = ""
	@Published public var isLoadingChat: Bool = false
	@Published public var suggestedPrompts: [String] = []
	@Published public var isShowingSettings: Bool = false

	let initialText: String
	let initialTitle: String?
	let inputType: InputType

	private let settingsService = SettingsService.shared
	private let usageTracker = UsageTrackerService.shared
	private let aiService = AIService.shared

	public init(initialText: String, initialTitle: String?, inputType: InputType) {
		self.initialText = initialText
		self.initialTitle = initialTitle
		self.inputType = inputType
	}

	public func retrySummary() async throws {
		self.summaryResult = nil
		self.streamingSummaryText = ""
		self.chatMessages = []
		try await processSummary()
	}

	public func processSummary() async throws {
		guard
			!initialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		else {
			throw WebParserError.parsingFailed
		}

		isLoadingSummary = true
		let summaryLength = settingsService.selectedSummaryLength
		let language = settingsService.summaryLanguage
		let summaryStyle = settingsService.selectedSummaryStyle

		//Make streaming summary

		let stream =
			inputType == .youtube
			? aiService.summarizeYouTubeStream(
				text: initialText, summaryLength: summaryLength, language: language,
				summaryStyle: summaryStyle)
			: aiService.summarizeStream(
				text: initialText, summaryLength: summaryLength, language: language,
				summaryStyle: summaryStyle)

		print("Stream \(stream)")
		for try await chunk in stream {
			streamingSummaryText += chunk
		}

		let minutesSaved = TimeSavingCalculator.calculateMinutesSaved(
			originalText: initialText,
			summaryText: streamingSummaryText
		)

		summaryResult = SummaryResult(
			originalText: initialText, summaryText: streamingSummaryText, minutesSaved: minutesSaved
		)

		await handleSummarySuccess(
			originalText: initialText,
			summaryText: streamingSummaryText,
			minutesSaved: minutesSaved
		)

		usageTracker.addToTotalMinutesSaved(minutesSaved)
		usageTracker.incrementAPICallCount()
		isLoadingSummary = false

		// Attempt review prompt as soon as a summary succeeds (main app only)
		#if canImport(UIKit) && !APP_EXTENSION
			if let scene = UIApplication.shared.connectedScenes
				.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
			{
				ReviewRequestService.shared.tryPromptInAppIfEligible(windowScene: scene)
			}
		#endif

		// Fetch suggested prompts after summary is generated
		await fetchSuggestedPrompts()
	}

	private func handleSummarySuccess(
		originalText: String, summaryText: String, minutesSaved: Double
	)
		async
	{
		summaryResult = SummaryResult(
			originalText: originalText,
			summaryText: summaryText,
			minutesSaved: minutesSaved
		)
	}

	public func fetchSuggestedPrompts() async {
		guard let summaryText = summaryResult?.summaryText, !summaryText.isEmpty else { return }
		suggestedPrompts = await aiService.generateSuggestedPrompts(
			for: summaryText,
			language: settingsService.summaryLanguage
		)
	}

	public func useSuggestedPrompt(_ prompt: String) {
		messageText = prompt
	}

	public func formattedTime(_ date: Date) -> String {
		let formatter = DateFormatter()
		formatter.timeStyle = .short
		return formatter.string(from: date)
	}

	public func sendMessage() async {
		guard
			!messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		else { return }
		let language = settingsService.summaryLanguage
		let userMessage = messageText.trimmingCharacters(
			in: .whitespacesAndNewlines)
		messageText = ""

		let userChatMessage = ChatMessage(
			content: userMessage, isFromUser: true)
		chatMessages.append(userChatMessage)

		isLoadingChat = true

		do {
			let aiChatMessage = ChatMessage(content: "", isFromUser: false)
			chatMessages.append(aiChatMessage)

			let stream =
				inputType == .youtube
				? aiService.chatYouTubeStream(
					message: userMessage, transcript: initialText, language: language)
				: aiService.chatStream(
					message: userMessage,
					context: initialText,
					language: language
				)

			for try await chunk in stream {
				aiChatMessage.content += chunk
			}

			usageTracker.incrementAPICallCount()
		} catch {
			// Handle error, maybe remove the placeholder
			if let lastMessage = chatMessages.last, !lastMessage.isFromUser {
				chatMessages.last?.content = "Error. Please try again!"
			}
		}
		isLoadingChat = false
	}

	public var isInputURL: Bool {
		isValidURL(initialText)
	}

	public var estimatedReadingTime: String? {
		guard !streamingSummaryText.isEmpty else { return nil }
		return TimeSavingCalculator.estimatedReadingTime(for: streamingSummaryText)
	}

	public func saveToHistory(modelContext: ModelContext) {
		guard let result = summaryResult else { return }
		let summary = SummaryItem(
			originalText: result.originalText,
			summaryText: result.summaryText,
			minutesSaved: result.minutesSaved,
			chatMessages: chatMessages,
			title: initialTitle
		)
		modelContext.insert(summary)
		try? modelContext.save()
		summaryResult = nil
		chatMessages = []

		// Debug: Print all summaries after save
		let fetchDescriptor = FetchDescriptor<SummaryItem>()
		if let allSummaries = try? modelContext.fetch(fetchDescriptor) {
			print(
				"[QuickSummary] All summaries in shared store after save: \(allSummaries)"
			)
		}
	}
}
