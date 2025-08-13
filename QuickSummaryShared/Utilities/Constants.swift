import Foundation
import LinkPresentation

public struct AppConstants {
	public static let averageReadingSpeedWPM: Double = 225

	public static let defaultCornerRadius: CGFloat = 12
	public static let defaultPadding: CGFloat = 16
	public static let smallPadding: CGFloat = 8

	public static let summaryPreviewLength = 100
	public static let originalTextPreviewLength = 50
	public static let maxChatMessageLength = 1000

	public static let defaultAnimationDuration: Double = 0.3
	public static let fastAnimationDuration: Double = 0.15

	public struct API {
		public static let geminiModel = "gemini-2.0-flash-001"
		public static let requestTimeout: TimeInterval = 30
		public static let maxRetries = 3
	}

	public struct UserDefaultsKeys {
		public static let selectedPreset = "selectedPreset"
		public static let isFirstLaunch = "isFirstLaunch"
		public static let totalMinutesSaved = "totalMinutesSaved"
		public static let totalSummariesCreated = "totalSummariesCreated"
		public static let totalAPICallsCount = "totalAPICallsCount"
		public static let lastUsedDate = "lastUsedDate"
	}

	public struct AppGroups {
		public static let identifier = "group.com.catboss.quicksummary"
		// Note: This needs to be configured in Xcode project settings
	}

	public struct DefaultPresets {
		public static let shortPrompt =
			"Provide a concise summary in 2-3 sentences that captures the key points."
		public static let normalPrompt =
			"Provide a clear summary in 1-2 paragraphs that covers the main ideas and important details."
		public static let detailedPrompt =
			"Provide a comprehensive summary that includes all major points, supporting details, and key insights."
	}

	public static let defaultSuggestedPrompts = [
		"What are the key takeaways?",
		"Can you explain this in simpler terms?",
		"What questions should I ask about this?",
		"What are the implications?",
		"How does this relate to current trends?",
	]
}

public struct ErrorMessages {
	public static let emptyInput =
		"Please enter some text or a URL to summarize."
	public static let invalidURL = "The provided URL is not valid."
	public static let networkError =
		"Network connection failed. Please check your internet connection."
	public static let parsingFailed =
		"Could not parse the webpage. Please try copying the text directly."
	public static let summaryFailed =
		"Failed to generate summary. Please try again."
	public static let emptyResponse =
		"The AI service returned an empty response."
	public static let chatFailed = "Failed to get response. Please try again."
}

public struct SuccessMessages {
	public static let summaryCreated = "Summary created successfully!"
	public static let dataReset = "All data has been reset."
	public static let settingsSaved = "Settings saved successfully!"
}

public func formatSecondsToHHMMSS(_ totalSeconds: Double) -> String {
	// Cast the Double to an Int to perform integer arithmetic
	let intTotalSeconds = Int(totalSeconds)

	let hours = intTotalSeconds / 3600
	let minutes = (intTotalSeconds % 3600) / 60
	let seconds = (intTotalSeconds % 3600) % 60

	return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}

public func isYouTubeURL(_ input: String) -> Bool {
	let patterns = [
		"youtube.com/watch?v=",
		"youtu.be/",
	]
	return patterns.contains { input.contains($0) }
}

public func isValidURL(_ input: String) -> Bool {
	guard let url = URL(string: input) else { return false }
	return url.scheme != nil && url.host != nil
}

public func isPDF(_ input: String) -> Bool {
	input.lowercased().contains(".pdf") || input.lowercased().contains("pdf")
}

public enum InputType {
	case pdf
	case youtube
	case url
	case text
}

public func getInputType(_ input: String) -> InputType {
	if isPDF(input) {
		return .pdf
	}
	if isYouTubeURL(input) {
		return .youtube
	}
	if isValidURL(input) {
		return .url
	}

	return .text
}

// MARK: - URL Title Fetching
public func fetchURLTitle(from urlString: String) async -> String? {
	guard isValidURL(urlString), let url = URL(string: urlString) else {
		return nil
	}

	return await withCheckedContinuation { continuation in
		let provider = LPMetadataProvider()
		provider.startFetchingMetadata(for: url) { metadata, error in
			if let metadata = metadata, let title = metadata.title, !title.isEmpty {
				continuation.resume(returning: title)
			} else {
				continuation.resume(returning: nil)
			}
		}
	}
}

public struct MyError: LocalizedError {
	let message: String
	public var errorDescription: String? { message }

	public init(message: String) {
		self.message = message
	}
}

/// Supported Gemini AI Models
public enum AIModel: String, CaseIterable, Identifiable {
	/// Gemini 2.5 Pro
	case gemini25Pro = "gemini-2.5-pro"
	/// Gemini 2.5 Flash
	case gemini25Flash = "gemini-2.5-flash"
	/// Gemini 2.5 Flash-Lite
	case gemini25FlashLite = "gemini-2.5-flash-lite"
	/// Gemini 2.0 Flash
	case gemini20Flash = "gemini-2.0-flash-001"
	/// Gemini 2.0 Flash-Lite
	case gemini20FlashLite = "gemini-2.0-flash-lite-001"

	/// String key for API usage
	public var key: String { rawValue }
	/// Unique identifier for Identifiable conformance
	public var id: String { rawValue }
	/// User-friendly display name
	public var title: String {
		switch self {
		case .gemini25Pro: return "Gemini 2.5 Pro"
		case .gemini25Flash: return "Gemini 2.5 Flash"
		case .gemini25FlashLite: return "Gemini 2.5 Flash‑Lite"
		case .gemini20Flash: return "Gemini 2.0 Flash"
		case .gemini20FlashLite: return "Gemini 2.0 Flash‑Lite"
		}
	}

	/// Short model description
	public var description: String {
		switch self {
		case .gemini25Pro:
			return "Most powerful model, ideal for complex summaries."
		case .gemini25Flash:
			return "Fast and capable, great for a balance of speed and quality."
		case .gemini25FlashLite:
			return "Lightweight and efficient, perfect for quick summaries."
		case .gemini20Flash:
			return "A previous generation fast and capable model."
		case .gemini20FlashLite:
			return "A previous generation lightweight and efficient model."
		}
	}
}

public enum SummaryStyle: String, CaseIterable, Identifiable {
	case `default`
	case keyPoints
	case simpleLanguage
	case actionItems
	case conversational
	case prosCons

	public var id: String { rawValue }
	public var title: String {
		switch self {
		case .default: return "Default"
		case .keyPoints: return "Key Points"
		case .simpleLanguage: return "Simple Language"
		case .actionItems: return "Action Items"
		case .conversational: return "Conversational"
		case .prosCons: return "Pros & Cons"
		}
	}
	public var description: String {
		switch self {
		case .default:
			return "Provides a summary that is easy to understand and covers the main points."
		case .keyPoints:
			return "Extracts the 5 most important key takeaways as a concise, numbered list."
		case .simpleLanguage:
			return "Summarizes using simple, clear, and easy-to-understand language."
		case .actionItems:
			return "Extracts actionable items, tasks, and recommendations as a bulleted list."
		case .conversational:
			return "Summarizes in a casual, engaging tone as if explained by a friend."
		case .prosCons:
			return "Analyzes the text and presents main positive and negative points in two lists."
		}
	}
	public var promptTemplate: String {
		switch self {
		case .default:
			return
				"Provide a clear summary in 1-2 paragraphs that covers the main ideas and important details."
		case .keyPoints:
			return
				"Extract the 5 most important key takeaways from the following text. Present them as a concise, numbered list. Each point must be a complete and self-contained sentence. Ensure the points are objective and directly supported by the text."
		case .simpleLanguage:
			return
				"Summarize the following text using simple, clear, and easy-to-understand language. Avoid jargon, complex sentences, and technical terms wherever possible. Use analogies if they help clarify the main concepts. The target audience is a smart high school student who is new to this topic."
		case .actionItems:
			return
				"Analyze the following text and extract only the actionable items, tasks, decisions, and recommendations. Ignore general discussion and background information. Present the results as a clear, bulleted list. If a task is assigned to someone or has a deadline, include that information."
		case .conversational:
			return
				"Summarize the following text in a casual, conversational, and engaging tone, as if you were explaining it to a curious friend. You can start with a phrase like 'So, here's the deal...' or 'Basically, what this is saying is...'. Use contractions and a friendly, first-person narrative style."
		case .prosCons:
			return
				"Analyze the following text, which discusses [topic of the text, e.g., 'the new iPhone']. Identify and extract the main positive points (Pros) and negative points (Cons). Present the results in two distinct lists under the headings 'Pros' and 'Cons'."
		}
	}
}

public enum SummaryLength: String, CaseIterable, Identifiable {
	case short
	case medium
	case detailed

	public var id: String { rawValue }
	public var title: String {
		switch self {
		case .short: return "Short"
		case .medium: return "Medium"
		case .detailed: return "Detailed"
		}
	}
	public var description: String {
		switch self {
		case .short:
			return "Concise summary with only the most essential points."
		case .medium:
			return "Balanced summary covering main ideas and key details."
		case .detailed:
			return "Comprehensive summary with extensive details and context."
		}
	}

	public var lengthModifier: String {
		switch self {
		case .short:
			return
				"Produce 2–4 bullet points and no more than ~100 words. Focus only on essential points. Do not include background, examples, quotes, sub‑points, or tangential details."
		case .medium:
			return
				"Produce 5–8 bullet points or 2–3 short paragraphs (about 150–250 words). Cover main ideas and key details. Do not attempt exhaustive coverage or deep background."
		case .detailed:
			return
				"Produce 10–16 bullet points or 4–6 paragraphs (at least ~350–600 words). Include context, caveats, brief examples, and important nuances for comprehensive coverage."
		}
	}
}

// MARK: - Model Selection Mode
public enum ModelSelectionMode: String, CaseIterable, Identifiable {
	case smart
	case manual

	public var id: String { rawValue }
	public var title: String {
		switch self {
		case .smart: return "Smart Default"
		case .manual: return "Manual"
		}
	}
	public var description: String {
		switch self {
		case .smart:
			return
				"Automatically chooses among fast, cost‑efficient models based on your content and summary length."
		case .manual:
			return "Select a specific model to use for all requests."
		}
	}
}

public func hideKeyboard() {
	#if canImport(UIKit)
		UIApplication.shared.sendAction(
			#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
	#endif
}
