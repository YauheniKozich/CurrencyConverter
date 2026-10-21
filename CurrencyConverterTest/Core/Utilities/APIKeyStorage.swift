//
//  APIKeyStorage.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 14.03.26.
//

import Foundation

/// Хранилище API-ключа в общей Keychain-группе приложения и виджета.
final class APIKeyStorage {
    
    private let keychain: KeychainHelper
    private let legacyKeychain: KeychainHelper
    private let service: String
    private let account: String
    
    init(
        keychain: KeychainHelper = KeychainHelper(accessGroup: ConfigurationDefaults.keychainAccessGroup),
        service: String,
        account: String
    ) {
        self.keychain = keychain
        self.legacyKeychain = KeychainHelper()
        self.service = service
        self.account = account
    }

    convenience init() {
        self.init(
            service: ConfigurationDefaults.keychainService,
            account: ConfigurationDefaults.keychainAccount
        )
    }
    
    /// Сохраняет API-ключ в Keychain без копирования в UserDefaults.
    @discardableResult
    func save(_ key: String) -> Bool {
        guard !key.isEmpty else {
            Logger.log("Попытка сохранить пустой API ключ", level: .warning)
            return false
        }

        guard keychain.saveString(key, service: service, account: account) else {
            Logger.log("Не удалось сохранить API ключ в Keychain", level: .error)
            return false
        }
        // A query without an access group also matches the shared item.
        // Never delete through the legacy helper after writing the current key.
        removeLegacyDefaultsKey()
        Logger.log("API ключ сохранён в Keychain", level: .debug)
        return true
    }
    
    /// Загружает API-ключ и однократно переносит старые значения в общую Keychain-группу.
    func load() -> String? {
        if let key = keychain.readString(service: service, account: account), !key.isEmpty {
            removeLegacyDefaultsKey()
            Logger.log("API ключ загружен из Keychain", level: .debug)
            return key
        }

        if let legacyKey = legacyKeychain.readString(service: service, account: account),
           migrate(legacyKey) {
            removeLegacyDefaultsKey()
            return legacyKey
        }

        let oldDefaults = [
            UserDefaults(suiteName: "group.com.currencyconverter"),
            UserDefaults.standard
        ]
        for defaults in oldDefaults {
            guard let legacyKey = defaults?.string(forKey: "CurrencyAPIKey"),
                  !legacyKey.isEmpty else { continue }
            guard migrate(legacyKey) else { return nil }
            removeLegacyDefaultsKey()
            return legacyKey
        }

        return nil
    }
    
    /// Удаляет API-ключ из текущего и прежних хранилищ.
    func delete() {
        keychain.delete(service: service, account: account)
        legacyKeychain.delete(service: service, account: account)
        removeLegacyDefaultsKey()
        Logger.log("API ключ удалён из Keychain", level: .debug)
    }

    private func migrate(_ key: String) -> Bool {
        guard keychain.saveString(key, service: service, account: account) else {
            Logger.log("Не удалось перенести API ключ в общую группу Keychain", level: .error)
            return false
        }
        Logger.log("Старый API ключ перенесён в общую группу Keychain", level: .debug)
        return true
    }

    private func removeLegacyDefaultsKey() {
        UserDefaults(suiteName: "group.com.currencyconverter")?.removeObject(forKey: "CurrencyAPIKey")
        UserDefaults.standard.removeObject(forKey: "CurrencyAPIKey")
    }
}
