import FirebaseAI
import Foundation

@MainActor
public class AIService: ObservableObject {
	public static let shared = AIService()

	private let ai: FirebaseAI

	private init() {
		// Get Firebase API key from GoogleService-Info.plist
		self.ai = FirebaseAI.firebaseAI(backend: .googleAI())
	}

	// Computed property to get the current model based on settings
	private var model: GenerativeModel {
		ai.generativeModel(modelName: SettingsService.shared.selectedAIModel.key)
	}

	/// Summarizes the given text using the specified style and length, returning a stream of text chunks.
	public func summarizeStream(
		text: String, summaryLength: SummaryLength = .medium, language: String = "en",
		summaryStyle: SummaryStyle = .default
	)
		-> AsyncThrowingStream<
			String, Error
		>
	{
		print(
			"[AIService] Using AI model: \(SettingsService.shared.selectedAIModel.title) [key: \(SettingsService.shared.selectedAIModel.key)]"
		)
		print("[AIService] Using summary style: \(summaryStyle.title)")
		print("[AIService] Using summary length: \(summaryLength.title)")
		return AsyncThrowingStream { continuation in
			Task {
				do {
					let prompt = buildPrompt(
						with: text, language: language, summaryStyle: summaryStyle,
						summaryLength: summaryLength)
					let contentStream = try model.generateContentStream(prompt)
					for try await chunk in contentStream {
						guard let text = chunk.text else {
							throw AIServiceError.emptyResponse
						}
						continuation.yield(text)
					}
					continuation.finish()
				} catch {
					continuation.finish(throwing: error)
				}
			}
		}
	}

	/// Generates a chat response for follow-up questions about a summary, returning a stream of text chunks.
	public func chatStream(message: String, context: String, language: String = "en")
		-> AsyncThrowingStream<String, Error>
	{
		return AsyncThrowingStream { continuation in
			Task {
				do {
					let languageName =
						Locale.current.localizedString(forLanguageCode: language)
						?? "English"
					let prompt = """
						Based on this content:
						\(context)

						User question: \(message)

						Please provide a helpful and accurate response based on the content above in \(languageName).
						"""
					let contentStream = try model.generateContentStream(prompt)
					for try await chunk in contentStream {
						guard let text = chunk.text else {
							throw AIServiceError.emptyResponse
						}
						continuation.yield(text)
					}
					continuation.finish()
				} catch {
					continuation.finish(throwing: error)
				}
			}
		}
	}

	/// Generates suggested chat prompts for a given summary
	public func generateSuggestedPrompts(for content: String, language: String = "en") async
		-> [String]
	{
		let defaultPrompts = [
			"What are the key takeaways?",
			"Can you explain this in simpler terms?",
			"What questions should I ask about this?",
			"What are the implications?",
			"How does this relate to current trends?",
		]

		do {
			let languageName =
				Locale.current.localizedString(forLanguageCode: language) ?? "English"
			let prompt = """
				Based on the following text, generate three concise and relevant follow-up questions in \(languageName).
				Return only the questions, each on a new line.

				Text: "\(content)"
				"""
			let response = try await model.generateContent(prompt)

			guard let text = response.text else {
				return defaultPrompts
			}

			let prompts = text.split(whereSeparator: \.isNewline).map { String($0) }
			return prompts.isEmpty ? defaultPrompts : prompts
		} catch {
			print("Error generating suggested prompts: \(error.localizedDescription)")
			return defaultPrompts
		}
	}

	public func summarizeYouTubeStream(
		text: String, summaryLength: SummaryLength = .medium, language: String = "en",
		summaryStyle: SummaryStyle = .default
	)
		-> AsyncThrowingStream<
			String, Error
		>
	{
		print(
			"[AIService] Using AI model: \(SettingsService.shared.selectedAIModel.title) [key: \(SettingsService.shared.selectedAIModel.key)]"
		)
		print("[AIService] Using summary style: \(summaryStyle.title)")
		print("[AIService] Using summary length: \(summaryLength.title)")
		return AsyncThrowingStream { continuation in
			Task {
				do {
					let prompt = buildYouTubePrompt(
						with: text, language: language, summaryStyle: summaryStyle,
						summaryLength: summaryLength)
					let contentStream: AsyncThrowingStream<GenerateContentResponse, any Error> =
						try model.generateContentStream(prompt)
					for try await chunk in contentStream {
						guard let text = chunk.text else {
							throw AIServiceError.emptyResponse
						}
						continuation.yield(text)
					}
					continuation.finish()
				} catch {
					continuation.finish(throwing: error)
				}
			}
		}
	}

	public func chatYouTubeStream(message: String, transcript: String, language: String = "en")
		-> AsyncThrowingStream<String, Error>
	{
		return AsyncThrowingStream { continuation in
			Task {
				do {
					let prompt = buildYouTubeChatPrompt(
						message: message, transcript: transcript, language: language)
					let contentStream = try model.generateContentStream(prompt)
					for try await chunk in contentStream {
						guard let text = chunk.text else {
							throw AIServiceError.emptyResponse
						}
						continuation.yield(text)
					}
					continuation.finish()
				} catch {
					continuation.finish(throwing: error)
				}
			}
		}
	}

	private func buildPrompt(
		with text: String, language: String = "en", summaryStyle: SummaryStyle = .default,
		summaryLength: SummaryLength = .medium
	)
		-> String
	{
		let stylePrompt = summaryStyle.promptTemplate
		let lengthModifier = summaryLength.lengthModifier

		let languageName =
			Locale.current.localizedString(forLanguageCode: language)
			?? "English"
		let languageInstruction = "Summarize in \(languageName)."
		return """
			\(languageInstruction)

			\(stylePrompt)

			\(lengthModifier)

			Content to summarize:
			\(text)

			Summary:
			"""
	}

	private func buildYouTubePrompt(
		with text: String, language: String = "en", summaryStyle: SummaryStyle = .default,
		summaryLength: SummaryLength = .medium
	)
		-> String
	{
		let stylePrompt = summaryStyle.promptTemplate
		let lengthModifier = summaryLength.lengthModifier

		let languageName =
			Locale.current.localizedString(forLanguageCode: language)
			?? "English"

		return """
			Summarize this YouTube video in \(languageName).
			\(stylePrompt)

			\(lengthModifier)

			Transcript:
			\(text)

			Please provide a concise summary with key points and include timestamps (e.g., [00:01:23]) for each main idea or section.
			Format the summary as a list of points with timestamps.

			Summary with timestamps:
			"""
	}

	private func buildYouTubeChatPrompt(
		message: String, transcript: String, language: String = "en"
	) -> String {
		let languageName =
			Locale.current.localizedString(forLanguageCode: language)
			?? "English"

		return """
			You are an expert at analyzing YouTube videos and answering questions about their content.

			Here is the YouTube Transcript:
			\(transcript)

			User question: \(message)

			Please answer the question in \(languageName) as if you had watched the video, referencing timestamps and video structure where relevant. If the user asks about a specific time, focus your answer on that section. If you don't know the answer, say so.
			"""
	}
}

public enum AIServiceError: LocalizedError {
	case emptyResponse
	case invalidResponse
	case networkError(String)

	public var errorDescription: String? {
		switch self {
		case .emptyResponse:
			return "The AI service returned an empty response."
		case .invalidResponse:
			return "The AI service returned an invalid response."
		case .networkError(let message):
			return "Network error: \(message)"
		}
	}
}
