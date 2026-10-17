//
//  APIKeyStorage.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 14.03.26.
//

import Foundation

/// Хранилище для API ключа (Keychain + синхронизация для расширений)
final class APIKeyStorage {
    
    private let keychain: KeychainHelper
    private let service: String
    private let account: String
    
    init(
        keychain: KeychainHelper = KeychainHelper(),
        service: String,
        account: String
    ) {
        self.keychain = keychain
        self.service = service
        self.account = account
    }

    convenience init() {
        self.init(
            keychain: KeychainHelper(),
            service: ConfigurationDefaults.keychainService,
            account: ConfigurationDefaults.keychainAccount
        )
    }
    
    /// Сохраняет API ключ в Keychain и UserDefaults для виджета
    func save(_ key: String) {
        guard !key.isEmpty else {
            Logger.log("Попытка сохранить пустой API ключ", level: .warning)
            return
        }
        
        keychain.saveString(key, service: service, account: account)
        UserDefaults(suiteName: "group.com.currencyconverter")?.set(key, forKey: "CurrencyAPIKey")
        UserDefaults.standard.set(key, forKey: "CurrencyAPIKey")
        Logger.log("API ключ сохранён в Keychain", level: .debug)
    }
    
    /// Загружает API ключ из Keychain или локального хранилища
    /// - Returns: API ключ или nil если не найден
    func load() -> String? {
        if let key = keychain.readString(service: service, account: account), !key.isEmpty {
            Logger.log("API ключ загружен из Keychain", level: .debug)
            return key
        }
        
        if let key = UserDefaults(suiteName: "group.com.currencyconverter")?.string(forKey: "CurrencyAPIKey"), !key.isEmpty {
            return key
        }
        
        return UserDefaults.standard.string(forKey: "CurrencyAPIKey")
    }
    
    /// Удаляет API ключ из Keychain и UserDefaults
    func delete() {
        keychain.delete(service: service, account: account)
        UserDefaults(suiteName: "group.com.currencyconverter")?.removeObject(forKey: "CurrencyAPIKey")
        UserDefaults.standard.removeObject(forKey: "CurrencyAPIKey")
        Logger.log("API ключ удалён из Keychain", level: .debug)
    }
}
