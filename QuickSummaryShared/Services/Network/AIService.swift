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

	// Resolve model based on Smart/Manual mode and lightweight heuristics
	private struct ModelContextInfo {
		let isYouTube: Bool
		let summaryLength: SummaryLength
		let contentCharCount: Int
	}

	private func resolvedModelKey(for ctx: ModelContextInfo) -> String {
		let settings = SettingsService.shared
		if settings.modelSelectionMode == .manual {
			return settings.selectedAIModel.key
		}

		// Smart Default: only consider 2.0 Flash‑Lite, 2.0 Flash, 2.5 Flash‑Lite
		// Heuristics prioritize RPM/cost
		if ctx.isYouTube {
			// Long/detailed YouTube -> 2.5 Flash‑Lite; otherwise 2.0 Flash
			if ctx.summaryLength == .detailed || ctx.contentCharCount > 6000 {
				return AIModel.gemini25FlashLite.key
			}
			return AIModel.gemini20Flash.key
		}

		// Text inputs
		if ctx.contentCharCount < 1200 || ctx.summaryLength == .short {
			return AIModel.gemini20FlashLite.key
		}
		if ctx.summaryLength == .detailed || ctx.contentCharCount > 6000 {
			return AIModel.gemini25FlashLite.key
		}
		return AIModel.gemini20Flash.key
	}

	private func model(for ctx: ModelContextInfo) -> GenerativeModel {
		let key = resolvedModelKey(for: ctx)
		return ai.generativeModel(modelName: key)
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
					print(prompt)
					let ctx = ModelContextInfo(
						isYouTube: false,
						summaryLength: summaryLength,
						contentCharCount: text.count
					)
					let contentStream = try model(for: ctx).generateContentStream(prompt)
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
					let fallbackCode = (language == "auto") ? "en" : language
					let fallbackLanguageName =
						Locale.current.localizedString(forLanguageCode: fallbackCode)
						?? "English"
					let prompt = """
						Language Policy:
						- Respond strictly in the same language as the user's question.
						- If you cannot confidently determine the language, respond in \(fallbackLanguageName).
						- Do not explain or mention the language choice. Start directly with the answer.

						Context:
						\(context)

						User question:
						\(message)
						"""
					let ctx = ModelContextInfo(
						isYouTube: false,
						summaryLength: .medium,
						contentCharCount: context.count
					)
					let contentStream = try model(for: ctx).generateContentStream(prompt)
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
			let fallbackCode = (language == "auto") ? "en" : language
			let fallbackLanguageName =
				Locale.current.localizedString(forLanguageCode: fallbackCode) ?? "English"
			let prompt: String
			if language == "auto" {
				prompt = """
					Language Policy:
					- Generate the questions in the same language as the provided text.
					- If you cannot determine the language, use \(fallbackLanguageName).
					- Return only the questions, each on a new line.

					Text:
					"""
					+ content
			} else {
				let languageName =
					Locale.current.localizedString(forLanguageCode: language) ?? "English"
				prompt = """
					Generate three concise and relevant follow-up questions in \(languageName).
					Return only the questions, each on a new line.

					Text:
					"""
					+ content
			}
			let ctx = ModelContextInfo(
				isYouTube: false,
				summaryLength: .medium,
				contentCharCount: content.count
			)
			let response = try await model(for: ctx).generateContent(prompt)

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
					print(prompt)
					let ctx = ModelContextInfo(
						isYouTube: true,
						summaryLength: summaryLength,
						contentCharCount: text.count
					)
					let contentStream: AsyncThrowingStream<GenerateContentResponse, any Error> =
						try model(for: ctx).generateContentStream(prompt)
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
					let ctx = ModelContextInfo(
						isYouTube: true,
						summaryLength: .medium,
						contentCharCount: transcript.count
					)
					let contentStream = try model(for: ctx).generateContentStream(prompt)
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

		let fallbackCode = (language == "auto") ? "en" : language
		let fallbackLanguageName =
			Locale.current.localizedString(forLanguageCode: fallbackCode)
			?? "English"

		if language == "auto" {
			return """
				Language Policy:
				- Output MUST be entirely in the predominant natural language of the content to summarize. If unclear or mixed, use \(fallbackLanguageName).
				- Do not explain or mention language choice. Start directly with the summary.

				Content to summarize:
				\(text)

				Instructions:
				1) Follow this style: \(stylePrompt)
				2) Enforce this length guidance: \(lengthModifier)
				"""
		} else {
			let languageName =
				Locale.current.localizedString(forLanguageCode: language)
				?? "English"
			return """
				Language Policy:
				- Output MUST be entirely in \(languageName).
				- Do not use any other language or mention language choice.

				Instructions:
				1) Follow this style: \(stylePrompt)
				2) Enforce this length guidance: \(lengthModifier)

				Content to summarize:
				\(text)
				"""
		}
	}

	private func buildYouTubePrompt(
		with text: String, language: String = "en", summaryStyle: SummaryStyle = .default,
		summaryLength: SummaryLength = .medium
	)
		-> String
	{
		let stylePrompt = summaryStyle.promptTemplate
		let lengthModifier = summaryLength.lengthModifier

		let fallbackCode = (language == "auto") ? "en" : language
		let fallbackLanguageName =
			Locale.current.localizedString(forLanguageCode: fallbackCode)
			?? "English"

		if language == "auto" {
			return """
				Language Policy:
				- Output MUST be entirely in the predominant natural language of the transcript. If unclear or mixed, use \(fallbackLanguageName).
				- Do not explain or mention language choice.

				Transcript:
				\(text)

				Instructions:
				1) Follow this style: \(stylePrompt)
				2) Enforce this length guidance: \(lengthModifier)
				3) Include timestamps like [HH:MM:SS] for each point.
				"""
		} else {
			let languageName =
				Locale.current.localizedString(forLanguageCode: language)
				?? "English"
			return """
				Language Policy:
				- Output MUST be entirely in \(languageName).
				- Do not use any other language or mention language choice.

				Instructions:
				1) Follow this style: \(stylePrompt)
				2) Enforce this length guidance: \(lengthModifier)
				3) Include timestamps like [HH:MM:SS] for each point.

				Transcript:
				\(text)
				"""
		}
	}

	private func buildYouTubeChatPrompt(
		message: String, transcript: String, language: String = "en"
	) -> String {
		let fallbackCode = (language == "auto") ? "en" : language
		let fallbackLanguageName =
			Locale.current.localizedString(forLanguageCode: fallbackCode)
			?? "English"

		return """
			Language Policy:
			- Respond strictly in the same language as the user's question.
			- If you cannot confidently determine the language, respond in \(fallbackLanguageName).
			- Do not explain or mention language choice. Start directly with the answer.

			You are an expert at analyzing YouTube videos and answering questions about their content.

			Here is the YouTube Transcript:
			\(transcript)

			User question:
			\(message)
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
