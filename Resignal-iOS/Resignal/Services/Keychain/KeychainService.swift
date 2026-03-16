//
//  KeychainService.swift
//  Resignal
//
//  Generic Keychain CRUD service for secure storage of sensitive data.
//

import Foundation
import Security

// MARK: - Protocol

protocol KeychainServiceProtocol: Sendable {
    func save(_ data: Data, forKey key: String) throws
    func load(forKey key: String) -> Data?
    func delete(forKey key: String)
}

extension KeychainServiceProtocol {
    func saveString(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        try save(data, forKey: key)
    }

    func loadString(forKey key: String) -> String? {
        guard let data = load(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Implementation

final class KeychainService: KeychainServiceProtocol, @unchecked Sendable {

    private let serviceName: String
    private let lock = NSLock()

    init(serviceName: String = "app.resignal") {
        self.serviceName = serviceName
    }

    func save(_ data: Data, forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func load(forKey key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return data
    }

    func delete(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed with status \(status)"
        }
    }
}
