import Foundation
import Security

enum KeychainError: LocalizedError {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in keychain"
        case .duplicateItem:
            return "Item already exists in keychain"
        case .invalidData:
            return "Invalid data format"
        case .unexpectedStatus(let status):
            return "Keychain error: \(status)"
        }
    }
}

enum KeychainKey: String {
    case monobankToken = "com.denysrumiantsev.renso.monobank_token"
    case coinmarketcapAPIKey = "com.denysrumiantsev.renso.coinmarketcap_api_key"
}

final class KeychainService {
    static let shared = KeychainService()

    private init() {}

    // MARK: - Save

    func save(_ string: String, for key: KeychainKey) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        try save(data, for: key)
    }

    func save(_ data: Data, for key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        switch status {
        case errSecSuccess:
            return

        case errSecDuplicateItem:
            // Item exists, update it
            try update(data, for: key)

        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Retrieve

    func retrieve(for key: KeychainKey) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.invalidData
            }
            return data

        case errSecItemNotFound:
            throw KeychainError.itemNotFound

        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func retrieveString(for key: KeychainKey) throws -> String {
        let data = try retrieve(for: key)

        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return string
    }

    // MARK: - Update

    func update(_ string: String, for key: KeychainKey) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        try update(data, for: key)
    }

    func update(_ data: Data, for key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        switch status {
        case errSecSuccess:
            return

        case errSecItemNotFound:
            throw KeychainError.itemNotFound

        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Delete

    func delete(for key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        switch status {
        case errSecSuccess, errSecItemNotFound:
            return

        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Check Existence

    func exists(for key: KeychainKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Convenience Methods

    var monobankToken: String? {
        get {
            try? retrieveString(for: .monobankToken)
        }
        set {
            if let value = newValue {
                try? save(value, for: .monobankToken)
            } else {
                try? delete(for: .monobankToken)
            }
        }
    }

    var coinmarketcapAPIKey: String? {
        get {
            try? retrieveString(for: .coinmarketcapAPIKey)
        }
        set {
            if let value = newValue {
                try? save(value, for: .coinmarketcapAPIKey)
            } else {
                try? delete(for: .coinmarketcapAPIKey)
            }
        }
    }
}
