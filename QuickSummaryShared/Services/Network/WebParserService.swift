import Foundation

public class WebParserService {
	private init() {}

	/// Parses clean text from a URL using NSAttributedString HTML parsing
	public static func parseWebContent(from url: URL) async throws -> String {
		// Fetch the HTML content
		let (data, _) = try await URLSession.shared.data(from: url)

		guard let html = String(data: data, encoding: .utf8) else {
			throw WebParserError.invalidEncoding
		}

		// Use NSAttributedString to parse HTML content intelligently
		return await parseHTMLContent(html)
	}

	/// Parse HTML content using NSAttributedString on main actor
	@MainActor
	private static func parseHTMLContent(_ html: String) -> String {
		guard let data = html.data(using: .utf8) else {
			return stripBasicHTML(from: html)
		}

		do {
			let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
				.documentType: NSAttributedString.DocumentType.html,
				.characterEncoding: String.Encoding.utf8.rawValue,
			]

			let attributedString = try NSAttributedString(
				data: data, options: options, documentAttributes: nil)
			let cleanText = attributedString.string

			// Clean up excessive whitespace and newlines
			let cleanedText =
				cleanText
				.components(separatedBy: .whitespacesAndNewlines)
				.filter { !$0.isEmpty }
				.joined(separator: " ")
				.trimmingCharacters(in: .whitespacesAndNewlines)

			// If NSAttributedString parsing resulted in very short content, fall back to basic stripping
			return cleanedText.count > 50
				? cleanedText : stripBasicHTML(from: html)
		} catch {
			// Fall back to basic HTML stripping if NSAttributedString parsing fails
			return stripBasicHTML(from: html)
		}
	}

	/// Basic HTML stripping as fallback
	private static func stripBasicHTML(from html: String) -> String {
		let htmlTags = try? NSRegularExpression(
			pattern: "<[^>]+>", options: .caseInsensitive)
		let range = NSRange(location: 0, length: html.count)
		let strippedString =
			htmlTags?.stringByReplacingMatches(
				in: html, options: [], range: range, withTemplate: "")
			?? html

		// Clean up whitespace
		let cleanedString =
			strippedString
			.components(separatedBy: .whitespacesAndNewlines)
			.filter { !$0.isEmpty }
			.joined(separator: " ")

		return cleanedString
	}

	/// Converts a string to URL if valid
	public static func url(from string: String) -> URL? {
		// Add https:// if no scheme is provided
		let urlString = string
		if isValidURL(urlString) {
			return URL(string: urlString)
		} else {
			return nil
		}
	}
}

public enum WebParserError: LocalizedError {
	case invalidURL
	case invalidEncoding
	case networkError(String)
	case parsingFailed

	public var errorDescription: String? {
		switch self {
		case .invalidURL:
			return "The provided URL is not valid."
		case .invalidEncoding:
			return "Could not decode the web content."
		case .networkError(let message):
			return "Network error: \(message)"
		case .parsingFailed:
			return "Could not parse the web content."
		}
	}
}
