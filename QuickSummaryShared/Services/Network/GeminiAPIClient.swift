import Foundation

/// Client for making direct REST API calls to the Gemini API
@MainActor
public class GeminiAPIClient {
    public static let shared = GeminiAPIClient()

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let session = URLSession.shared

    private init() {}

    // MARK: - Public Methods

    /// Generates content using the Gemini API (non-streaming)
    /// - Parameters:
    ///   - modelKey: The model to use (e.g., "gemini-2.0-flash-001")
    ///   - prompt: The text prompt to send
    /// - Returns: The generated text response
    /// - Throws: GeminiAPIError if the request fails
    public func generateContent(modelKey: String, prompt: String) async throws -> String {
        guard let apiKey = try KeychainService.shared.getAPIKey() else {
            throw GeminiAPIError.missingAPIKey
        }

        let endpoint = "\(baseURL)/models/\(modelKey):generateContent"
        guard let url = URL(string: endpoint) else {
            throw GeminiAPIError.invalidURL
        }

        let requestBody = GeminiStreamRequest(
            contents: [
                GeminiStreamContent(
                    parts: [GeminiPart(text: prompt)]
                )
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw GeminiAPIError.encodingFailed(error)
        }

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw GeminiAPIError.invalidAPIKey
            } else if httpResponse.statusCode == 429 {
                throw GeminiAPIError.rateLimitExceeded
            } else if httpResponse.statusCode >= 500 {
                throw GeminiAPIError.serverError(httpResponse.statusCode)
            } else if httpResponse.statusCode != 200 {
                throw GeminiAPIError.httpError(httpResponse.statusCode)
            }
        }

        do {
            let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
            return response.candidates.first?.content.parts.first?.text ?? ""
        } catch {
            throw GeminiAPIError.decodingFailed(error)
        }
    }

    /// Generates content using the Gemini API (streaming)
    /// - Parameters:
    ///   - modelKey: The model to use (e.g., "gemini-2.0-flash-001")
    ///   - prompt: The text prompt to send
    /// - Returns: AsyncThrowingStream of text chunks
    public func generateContentStream(modelKey: String, prompt: String) -> AsyncThrowingStream<
        String, Error
    > {
		print("Called custom with api key")
        return AsyncThrowingStream<String, Error> { continuation in
            Task {
                do {
                    guard let apiKey = try KeychainService.shared.getAPIKey() else {
                        continuation.finish(throwing: GeminiAPIError.missingAPIKey)
                        return
                    }

                    let endpoint = "\(baseURL)/models/\(modelKey):streamGenerateContent?alt=sse"
                    guard let url = URL(string: endpoint) else {
                        continuation.finish(throwing: GeminiAPIError.invalidURL)
                        return
                    }

                    let requestBody = GeminiStreamRequest(
                        contents: [
                            GeminiStreamContent(
                                parts: [GeminiPart(text: prompt)]
                            )
                        ]
                    )

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

                    do {
                        request.httpBody = try JSONEncoder().encode(requestBody)
                    } catch {
                        continuation.finish(throwing: GeminiAPIError.encodingFailed(error))
                        return
                    }

                    let (bytes, response) = try await session.bytes(for: request)

                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                            continuation.finish(throwing: GeminiAPIError.invalidAPIKey)
                            return
                        } else if httpResponse.statusCode == 429 {
                            continuation.finish(throwing: GeminiAPIError.rateLimitExceeded)
                            return
                        } else if httpResponse.statusCode >= 500 {
                            continuation.finish(
                                throwing: GeminiAPIError.serverError(httpResponse.statusCode))
                            return
                        } else if httpResponse.statusCode != 200 {
                            continuation.finish(
                                throwing: GeminiAPIError.httpError(httpResponse.statusCode))
                            return
                        }
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonData = String(line.dropFirst(6))  // Remove "data: " prefix

                            // Skip empty lines and [DONE] marker
                            if jsonData.isEmpty
                                || jsonData.trimmingCharacters(in: .whitespaces) == "[DONE]"
                            {
                                print("[GeminiAPIClient] Skipping empty or DONE marker")
                                continue
                            }

                            do {
                                if let data = jsonData.data(using: .utf8) {
                                    let response = try JSONDecoder().decode(
                                        GeminiResponse.self, from: data)
                                    if let text = response.candidates.first?.content.parts.first?
                                        .text
                                    {
                                        continuation.yield(text)
                                    } else {
                                        print("[GeminiAPIClient] No text found in response")
                                    }
                                }
                            } catch {
                                // Continue on individual chunk parsing errors
                                print("[GeminiAPIClient] Failed to parse chunk: \(error)")
                                print("[GeminiAPIClient] Raw chunk data: \(jsonData)")
                                continue
                            }
                        }
                    }

                    continuation.finish()

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Data Models

private struct GeminiRequest: Codable {
    let contents: [GeminiContent]
}

private struct GeminiContent: Codable {
    let role: String
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String
}

private struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Codable {
    let content: GeminiContent
}

// MARK: - Streaming-specific models (without role field)

private struct GeminiStreamRequest: Codable {
    let contents: [GeminiStreamContent]
}

private struct GeminiStreamContent: Codable {
    let parts: [GeminiPart]
}

// MARK: - Error Types

public enum GeminiAPIError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case invalidURL
    case rateLimitExceeded
    case serverError(Int)
    case httpError(Int)
    case encodingFailed(Error)
    case decodingFailed(Error)
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key found. Please add your Gemini API key in settings."
        case .invalidAPIKey:
            return "Invalid API key. Please check your Gemini API key in settings."
        case .invalidURL:
            return "Invalid API URL."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .httpError(let code):
            return "HTTP error (\(code)). Please try again."
        case .encodingFailed(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
