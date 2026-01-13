import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .duplicateItem:
            return "Item already exists in keychain"
        case .itemNotFound:
            return "Item not found in keychain"
        case .unexpectedStatus(let status):
            return "Keychain error: \(status)"
        case .invalidData:
            return "Invalid data format"
        }
    }
}

class KeychainService {
    static let shared = KeychainService()

    private let serviceName = "com.jonathanprocter.weeklyplanner"

    private init() {}

    // MARK: - Core Operations

    func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Try to delete existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func retrieve(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return value
    }

    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func hasKey(_ key: String) -> Bool {
        do {
            return try retrieve(key: key) != nil
        } catch {
            return false
        }
    }

    // MARK: - Convenience Properties

    private enum Keys {
        static let claudeAPIKey = "claude_api_key"
        static let openAIAPIKey = "openai_api_key"
        static let elevenLabsAPIKey = "elevenlabs_api_key"
        static let elevenLabsVoiceId = "elevenlabs_voice_id"
    }

    var claudeAPIKey: String? {
        get { try? retrieve(key: Keys.claudeAPIKey) }
        set {
            if let value = newValue {
                try? save(key: Keys.claudeAPIKey, value: value)
            } else {
                try? delete(key: Keys.claudeAPIKey)
            }
        }
    }

    var openAIAPIKey: String? {
        get { try? retrieve(key: Keys.openAIAPIKey) }
        set {
            if let value = newValue {
                try? save(key: Keys.openAIAPIKey, value: value)
            } else {
                try? delete(key: Keys.openAIAPIKey)
            }
        }
    }

    var elevenLabsAPIKey: String? {
        get { try? retrieve(key: Keys.elevenLabsAPIKey) }
        set {
            if let value = newValue {
                try? save(key: Keys.elevenLabsAPIKey, value: value)
            } else {
                try? delete(key: Keys.elevenLabsAPIKey)
            }
        }
    }

    var elevenLabsVoiceId: String? {
        get { try? retrieve(key: Keys.elevenLabsVoiceId) }
        set {
            if let value = newValue {
                try? save(key: Keys.elevenLabsVoiceId, value: value)
            } else {
                try? delete(key: Keys.elevenLabsVoiceId)
            }
        }
    }

    // MARK: - Validation

    var hasClaudeKey: Bool { hasKey(Keys.claudeAPIKey) }
    var hasOpenAIKey: Bool { hasKey(Keys.openAIAPIKey) }
    var hasElevenLabsKey: Bool { hasKey(Keys.elevenLabsAPIKey) }

    var hasAnyAIKey: Bool { hasClaudeKey || hasOpenAIKey }
    var hasAllKeys: Bool { hasClaudeKey && hasOpenAIKey && hasElevenLabsKey }
}
