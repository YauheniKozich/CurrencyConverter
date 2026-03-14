//
//  KeychainHelper.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation
import Security

final class KeychainHelper {

    init() {}

    func saveString(_ string: String, service: String, account: String) {
        guard !string.isEmpty,
              let data = string.data(using: .utf8) else {
            return
        }
        save(data, service: service, account: account)
    }

    func readString(service: String, account: String) -> String? {
        guard let data = read(service: service, account: account),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    func delete(service: String, account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Private Methods

    private func save(_ data: Data, service: String, account: String) {
        delete(service: service, account: account)
        add(data, service: service, account: account)
    }

    private func add(_ data: Data, service: String, account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func read(service: String, account: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              !data.isEmpty else {
            return nil
        }
        return data
    }
}
