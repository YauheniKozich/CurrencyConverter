//
//  KeychainHelper.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

final class KeychainHelper {
    static let shared = KeychainHelper()

    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
        case itemNotFound
        case invalidData
    }

    func save(_ data: Data, service: String, account: String) {
        do {
            try saveThrows(data, service: service, account: account)
        } catch {
            Logger.log("Keychain save error: \(error)")
        }
    }

    private func saveThrows(_ data: Data, service: String, account: String) throws {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary

        let attributesToUpdate = [kSecValueData: data] as CFDictionary

        let status = SecItemUpdate(query, attributesToUpdate)
        if status == errSecItemNotFound {
            var newItem = query as! [CFString: Any]
            newItem[kSecValueData] = data

            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            if addStatus != errSecSuccess {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func read(service: String, account: String) -> Data? {
        do {
            return try readThrows(service: service, account: account)
        } catch {
            Logger.log("Keychain read error: \(error)")
            return nil
        }
    }

    private func readThrows(service: String, account: String) throws -> Data {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary

        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)

        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    func saveString(_ string: String, service: String, account: String) {
        guard let data = string.data(using: .utf8) else {
            Logger.log("Cannot convert string to data")
            return
        }
        save(data, service: service, account: account)
    }

    func readString(service: String, account: String) -> String? {
        guard let data = read(service: service, account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(service: String, account: String) {
        do {
            try deleteThrows(service: service, account: account)
        } catch {
            Logger.log("Keychain delete error: \(error)")
        }
    }

    private func deleteThrows(service: String, account: String) throws {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary

        let status = SecItemDelete(query)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
