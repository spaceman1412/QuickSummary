import Foundation
import Security

/// Service for securely storing and retrieving the Gemini API key using App Group Keychain
@MainActor
public class KeychainService {
    public static let shared = KeychainService()

    private let service = "com.catboss.quicksummary.gemini-api"
    private let account = "gemini-api-key"
    private let accessGroup = "group.com.catboss.quicksummary"

    private init() {}

    // MARK: - Public Methods

    /// Saves the Gemini API key to the keychain
    /// - Parameter apiKey: The API key to store
    /// - Throws: KeychainError if the operation fails
    public func saveAPIKey(_ apiKey: String) throws {
        guard !apiKey.isEmpty else {
            throw KeychainError.invalidInput
        }

        let data = apiKey.data(using: .utf8)!

        // Delete existing key first
        try? deleteAPIKey()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: accessGroup,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Retrieves the Gemini API key from the keychain
    /// - Returns: The stored API key, or nil if not found
    /// - Throws: KeychainError if the operation fails
    public func getAPIKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        if status != errSecSuccess {
            throw KeychainError.retrievalFailed(status)
        }

        guard let data = result as? Data,
            let apiKey = String(data: data, encoding: .utf8)
        else {
            throw KeychainError.invalidData
        }

        return apiKey
    }

    /// Deletes the Gemini API key from the keychain
    /// - Throws: KeychainError if the operation fails
    public func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: accessGroup,
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.deletionFailed(status)
        }
    }

    /// Checks if an API key is stored in the keychain
    /// - Returns: true if a key exists, false otherwise
    public func hasAPIKey() -> Bool {
        do {
            return try getAPIKey() != nil
        } catch {
            return false
        }
    }
}

// MARK: - KeychainError

public enum KeychainError: LocalizedError {
    case invalidInput
    case saveFailed(OSStatus)
    case retrievalFailed(OSStatus)
    case deletionFailed(OSStatus)
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Invalid API key input"
        case .saveFailed(let status):
            return "Failed to save API key to keychain (status: \(status))"
        case .retrievalFailed(let status):
            return "Failed to retrieve API key from keychain (status: \(status))"
        case .deletionFailed(let status):
            return "Failed to delete API key from keychain (status: \(status))"
        case .invalidData:
            return "Invalid data retrieved from keychain"
        }
    }
}
