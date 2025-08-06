import Foundation

#if canImport(PDFKit)
	import PDFKit
#endif
#if canImport(ZipArchive)
	import ZipArchive
#endif

public enum DocumentParserError: Error, LocalizedError {
	case unsupportedFormat
	case fileIsEncrypted
	case parsingFailed
	case noTextFound

	public var errorDescription: String? {
		switch self {
		case .unsupportedFormat:
			return
				"Unsupported file type. Please select a PDF or Word document."
		case .fileIsEncrypted:
			return
				"This document is password-protected and cannot be summarized."
		case .parsingFailed:
			return "Could not read this document. The file may be corrupted."
		case .noTextFound:
			return "This document contains no readable text."
		}
	}
}

public struct DocumentParserService {
	public static func extractText(from fileURL: URL) async throws -> String {
		let ext = fileURL.pathExtension.lowercased()
		if ext == "pdf" {
			return try extractTextFromPDF(fileURL)
		} else {
			print("called")
			throw DocumentParserError.unsupportedFormat
		}
	}

	private static func extractTextFromPDF(_ url: URL) throws -> String {
		guard let document: PDFDocument = PDFDocument(url: url) else {
			throw DocumentParserError.parsingFailed
		}
		if document.isEncrypted {
			throw DocumentParserError.fileIsEncrypted
		}
		var buffer = ""
		for i in 0..<document.pageCount {
			guard let page = document.page(at: i), let text = page.string else {
				continue
			}
			buffer += text
		}
		if buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			throw DocumentParserError.noTextFound
		}
		return buffer
	}
}
