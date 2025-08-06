import Foundation
import QuickSummaryShared
import SwiftData
import SwiftUI

@MainActor
class SummaryDetailViewModel: ObservableObject {
	@Published var messageText: String = ""
	@Published var isLoading: Bool = false
	@Published var errorMessage: String?
	@Published var showError: Bool = false
	@Published var chatMessages: [ChatMessage] = []
	@Published var suggestedPrompts: [String] = []

	private let aiService = AIService.shared
	private let usageTracker = UsageTrackerService.shared
	private let settingsService = SettingsService.shared

	var summaryItem: SummaryItem
	let inputType: InputType

	init(summaryItem: SummaryItem) {
		self.summaryItem = summaryItem
		// Initialize and sort chatMessages from the summaryItem
		self.chatMessages = summaryItem.chatMessages.sorted {
			$0.timestamp < $1.timestamp
		}

		self.inputType = getInputType(summaryItem.originalText)
	}

	/// Syncs the local chatMessages with SwiftData and sorts them
	func syncMessages() {
		chatMessages = summaryItem.chatMessages.sorted {
			$0.timestamp < $1.timestamp
		}
	}

	/// Fetches suggested prompts for the current summary
	func fetchSuggestedPrompts() async {
		suggestedPrompts = await aiService.generateSuggestedPrompts(
			for: summaryItem.summaryText,
			language: settingsService.summaryLanguage
		)
	}

	/// Sends a chat message and gets AI response via streaming.
	func sendMessage(_ context: ModelContext) async {
		guard
			!messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		else {
			return
		}
		let language = settingsService.summaryLanguage

		let userMessage = messageText.trimmingCharacters(
			in: .whitespacesAndNewlines)
		messageText = ""

		// Add user message to local array immediately for UI update
		let userChatMessage = ChatMessage(
			content: userMessage, isFromUser: true)
		chatMessages.append(userChatMessage)

		// Also add to SwiftData and save
		summaryItem.chatMessages.append(userChatMessage)
		try? context.save()

		isLoading = true
		errorMessage = nil

		do {
			// Create a placeholder for the AI's response and add to local array immediately
			let aiChatMessage = ChatMessage(content: "", isFromUser: false)
			chatMessages.append(aiChatMessage)

			// Also add to SwiftData
			summaryItem.chatMessages.append(aiChatMessage)

			// Get AI response stream
			let stream =
				inputType == .youtube
				? aiService.chatYouTubeStream(
					message: userMessage, transcript: summaryItem.originalText, language: language)
				: aiService.chatStream(
					message: userMessage,
					context: summaryItem.originalText,
					language: language
				)

			for try await chunk in stream {
				aiChatMessage.content += chunk
				// Update the local array by finding and updating the message
				if let index = chatMessages.firstIndex(where: {
					$0.id == aiChatMessage.id
				}) {
					chatMessages[index] = aiChatMessage
				}
			}

			// Track API usage and save
			usageTracker.incrementAPICallCount()
			try context.save()

		} catch {
			showErrorMessage(
				"Failed to get response: \(error.localizedDescription)")

			// If an error occurs, remove the placeholder AI message from both arrays
			if let lastMessage = chatMessages.last, !lastMessage.isFromUser {
				chatMessages.removeLast()
			}
			if let lastMessage = summaryItem.chatMessages.last,
				!lastMessage.isFromUser
			{
				context.delete(lastMessage)
				try? context.save()
			}
		}

		isLoading = false
	}

	/// Uses a suggested prompt as the message
	func useSuggestedPrompt(_ prompt: String) {
		messageText = prompt
	}

	/// Clears the current message
	func clearMessage() {
		messageText = ""
	}

	/// Shows an error message
	private func showErrorMessage(_ message: String) {
		errorMessage = message
		showError = true
	}

	/// Clears the current error
	func clearError() {
		errorMessage = nil
		showError = false
	}

	/// Formats the timestamp of a message
	func formattedTime(_ date: Date) -> String {
		let formatter = DateFormatter()
		formatter.timeStyle = .short
		return formatter.string(from: date)
	}
}
