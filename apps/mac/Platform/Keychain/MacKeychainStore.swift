import Foundation
import Security

// Securely stores pairing trust tokens in the macOS Keychain with app-specific access control.
public final class MacKeychainStore {
    private let service: String

    public init(service: String = "com.icherri.receiver.pairing") {
        self.service = service
    }

    public func saveTrustToken(_ token: String, for deviceID: String) throws {
        let data = Data(token.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: deviceID,
            kSecValueData: data,
            kSecAttrLabel: "iCherri pairing token — \(deviceID)",
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Remove existing before insert
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: deviceID
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw MacKeychainError.saveFailed(status)
        }
    }

    public func loadTrustToken(for deviceID: String) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: deviceID,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw MacKeychainError.loadFailed(status)
        }
        return String(data: data, encoding: .utf8)
    }

    public func allPairedDeviceIDs() throws -> [String] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecReturnAttributes: true,
            kSecMatchLimit: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let items = result as? [[CFString: Any]] else {
            throw MacKeychainError.loadFailed(status)
        }
        return items.compactMap { $0[kSecAttrAccount] as? String }
    }

    public func deleteTrustToken(for deviceID: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: deviceID
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw MacKeychainError.deleteFailed(status)
        }
    }
}

public enum MacKeychainError: Error {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
}
