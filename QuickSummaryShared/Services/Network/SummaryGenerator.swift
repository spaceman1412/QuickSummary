import Foundation
import YoutubeTranscript

public struct SummaryGenerator {
	public struct StreamingSummaryResult {
		public let chunk: String
		public let summarySoFar: String
		public let originalText: String
	}
	
	public static func processInput(input: String) async throws -> String {
		let type = getInputType(input)

		switch type {
		case .pdf:
			guard let url = URL(string: input) else {
				throw MyError(message: "Can't convert string to URL")
			}
			
			return try await DocumentParserService.extractText(from: url)
			
		case .youtube:
			// For YouTube, just use the URL as the content for the AI prompt
			let data = try await YoutubeTranscript.fetchTranscript(
				for: input)
			
			var transcript: [String] = []
			// The result is an array of TranscriptResponse objects.
			for line in data {
				// Format the offset to two decimal places for cleaner output
				let offset = formatSecondsToHHMMSS(line.offset)
				transcript.append("[\(offset)s] \(line.text)")
			}
			
			return transcript.joined(separator: " ")
			
		case .url:
			if let url = WebParserService.url(from: input) {
				let textToSummarize =
				try await WebParserService.parseWebContent(
					from: url)
				if textToSummarize.isEmpty {
					throw WebParserError.parsingFailed
				}
				return textToSummarize
			}
			throw WebParserError.invalidURL
		case .text:
			return input
		}
	}
}
