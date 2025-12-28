//
//  KeychainAPIKeyProvider.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 26.05.25.
//

import Foundation

final class KeychainAPIKeyProvider: APIKeyProviding {
    private let service: String
    private let account: String
    private let keychainHelper: KeychainManaging

    init(service: String, account: String, keychainHelper: KeychainManaging = KeychainHelper.shared) {
        self.service = service
        self.account = account
        self.keychainHelper = keychainHelper
    }

    convenience init(service: String, account: String) {
        self.init(service: service, account: account, keychainHelper: KeychainHelper.shared)
    }

    func loadAPIKey() -> String? {
        return keychainHelper.readString(service: service, account: account)
    }

    func saveAPIKey(_ key: String) {
        keychainHelper.saveString(key, service: service, account: account)
    }

    func deleteAPIKey() {
        keychainHelper.delete(service: service, account: account)
    }

    func initializeAPIKeyIfNeeded() {
        keychainHelper.initializeAPIKeyIfNeeded(service: service, account: account)
    }
}
