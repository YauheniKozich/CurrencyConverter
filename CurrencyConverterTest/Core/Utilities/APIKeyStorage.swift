//
//  APIKeyStorage.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 14.03.26.
//

import Foundation

/// Хранилище для API ключа (Keychain)
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
    
    /// Сохраняет API ключ в Keychain
    func save(_ key: String) {
        guard !key.isEmpty else {
            Logger.log("Попытка сохранить пустой API ключ", level: .warning)
            return
        }
        
        keychain.saveString(key, service: service, account: account)
        Logger.log("API ключ сохранён в Keychain", level: .debug)
    }
    
    /// Загружает API ключ из Keychain
    /// - Returns: API ключ или nil если не найден
    func load() -> String? {
        guard let key = keychain.readString(service: service, account: account),
              !key.isEmpty else {
            return nil
        }
        
        Logger.log("API ключ загружен из Keychain", level: .debug)
        return key
    }
    
    /// Удаляет API ключ из Keychain
    func delete() {
        keychain.delete(service: service, account: account)
        Logger.log("API ключ удалён из Keychain", level: .debug)
    }
}
