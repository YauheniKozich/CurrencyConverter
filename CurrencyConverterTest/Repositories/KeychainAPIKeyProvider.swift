//
//  KeychainAPIKeyProvider.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 26.05.25.
//

import Foundation

final class KeychainAPIKeyProvider: APIKeyProviding {
    private let service = "com.yourapp.currencyconverter"
    private let account = "CurrencyAPIKey"

    func loadAPIKey() -> String? {
        return KeychainHelper.shared.readString(service: service, account: account)
    }

    func saveAPIKey(_ key: String) {
        KeychainHelper.shared.saveString(key, service: service, account: account)
    }

    func deleteAPIKey() {
        KeychainHelper.shared.delete(service: service, account: account)
    }
}
