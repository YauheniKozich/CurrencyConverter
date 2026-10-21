//
//  KeychainHelper.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation
import Security

enum KeychainStringReadResult: Equatable, Sendable {
    case value(String)
    case notFound
    case temporarilyUnavailable(OSStatus)
    case failure(OSStatus)
}

final class KeychainHelper {

    private let accessGroup: String?

    init(accessGroup: String? = nil) {
        self.accessGroup = accessGroup
    }

    @discardableResult
    func saveString(_ string: String, service: String, account: String) -> Bool {
        guard !string.isEmpty,
              let data = string.data(using: .utf8) else {
            return false
        }
        return save(data, service: service, account: account)
    }

    func readString(service: String, account: String) -> String? {
        if case .value(let value) = readStringResult(service: service, account: account) {
            return value
        }
        return nil
    }

    func readStringResult(service: String, account: String) -> KeychainStringReadResult {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return Self.interpretReadResult(status: status, data: result as? Data)
    }

    static func interpretReadResult(status: OSStatus, data: Data?) -> KeychainStringReadResult {
        switch status {
        case errSecItemNotFound:
            return .notFound
        case errSecInteractionNotAllowed, errSecNotAvailable:
            return .temporarilyUnavailable(status)
        case errSecSuccess:
            guard let data, let value = String(data: data, encoding: .utf8), !value.isEmpty else {
                return .failure(errSecDecode)
            }
            return .value(value)
        default:
            return .failure(status)
        }
    }

    func delete(service: String, account: String) {
        let query = baseQuery(service: service, account: account)
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Private Methods

    private func save(_ data: Data, service: String, account: String) -> Bool {
        let query = baseQuery(service: service, account: account)
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard updateStatus == errSecItemNotFound else {
            return updateStatus == errSecSuccess
        }

        var addQuery = query
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    private func baseQuery(service: String, account: String) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }
        return query
    }
}
