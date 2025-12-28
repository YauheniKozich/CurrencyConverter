//
//  KeychainHelper.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

/// Протокол для управления Keychain
protocol KeychainManaging {
    func saveString(_ string: String, service: String, account: String)
    func readString(service: String, account: String) -> String?
    func delete(service: String, account: String)
    func initializeAPIKeyIfNeeded(service: String, account: String)
}

/// Утилита для работы с Keychain для безопасного хранения данных, таких как API-ключи.
final class KeychainHelper: KeychainManaging {

    static let shared = KeychainHelper()

    enum Constants {
        static let service = "com.yourapp.currencyconverter"
        static let account = "CurrencyAPIKey"
    }
    
    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
        case itemNotFound
        case invalidData
    }
    
    private init() {}
    
    /// Инициализирует API-ключ в Keychain, если он отсутствует или устарел.
    func initializeAPIKeyIfNeeded() {
        initializeAPIKeyIfNeeded(service: Constants.service, account: Constants.account)
    }

    func initializeAPIKeyIfNeeded(service: String, account: String) {
        if let existingKey = readString(service: service, account: account) {
            if let newKey = APIKeyLoader.loadAPIKey(), !newKey.isEmpty, newKey != existingKey {
                saveString(newKey, service: service, account: account)
                Logger.log("API-ключ обновлен в Keychain из Config.plist")
            }
            return
        }

        guard let key = APIKeyLoader.loadAPIKey(), !key.isEmpty else {
            Logger.log("Не удалось загрузить API-ключ из Config.plist или ключ пустой")
            return
        }
        saveString(key, service: service, account: account)
        Logger.log("API-ключ был записан в Keychain из Config.plist")
    }
    
    /// Сохраняет данные в Keychain.
    /// - Parameters:
    ///   - data: Данные для сохранения.
    ///   - service: Идентификатор сервиса.
    ///   - account: Идентификатор учетной записи.
    func save(_ data: Data, service: String, account: String) {
        do {
            try saveThrows(data, service: service, account: account)
        } catch {
            Logger.log("Keychain save error: \(error)")
        }
    }
    
    private func saveThrows(_ data: Data, service: String, account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let attributesToUpdate = [kSecValueData: data] as CFDictionary
        
        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate)
        if status == errSecItemNotFound {
            let newItem: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecValueData: data,
                kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            if addStatus == errSecDuplicateItem {
                Logger.log("Duplicate item detected, deleting old key and retrying add.")
                let deleteStatus = SecItemDelete(query as CFDictionary)
                if deleteStatus == errSecSuccess {
                    let retryAddStatus = SecItemAdd(newItem as CFDictionary, nil)
                    guard retryAddStatus == errSecSuccess else {
                        throw KeychainError.unexpectedStatus(retryAddStatus)
                    }
                    Logger.log("Keychain: Successfully replaced duplicate item.")
                } else {
                    throw KeychainError.unexpectedStatus(deleteStatus)
                }
            } else if addStatus != errSecSuccess {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Читает данные из Keychain.
    /// - Parameters:
    ///   - service: Идентификатор сервиса.
    ///   - account: Идентификатор учетной записи.
    /// - Returns: Данные из Keychain или nil, если произошла ошибка.
    func read(service: String, account: String) -> Data? {
        do {
            return try readThrows(service: service, account: account)
        } catch {
            Logger.log("Keychain read error: \(error)")
            return nil
        }
    }
    
    private func readThrows(service: String, account: String) throws -> Data {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            query[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemCopyMatching(query as CFDictionary, &result)
        }
        
        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        
        guard let data = result as? Data, !data.isEmpty else {
            throw KeychainError.invalidData
        }
        
        return data
    }
    
    /// Сохраняет строку в Keychain.
    /// - Parameters:
    ///   - string: Строка для сохранения.
    ///   - service: Идентификатор сервиса.
    ///   - account: Идентификатор учетной записи.
    func saveString(_ string: String, service: String, account: String) {
        guard !string.isEmpty else {
            Logger.log("Cannot save empty string to Keychain")
            return
        }
        guard let data = string.data(using: .utf8) else {
            Logger.log("Cannot convert string to UTF-8 data")
            return
        }
        save(data, service: service, account: account)
    }
    
    /// Читает строку из Keychain.
    /// - Parameters:
    ///   - service: Идентификатор сервиса.
    ///   - account: Идентификатор учетной записи.
    /// - Returns: Строка из Keychain или nil, если произошла ошибка.
    func readString(service: String, account: String) -> String? {
        guard let data = read(service: service, account: account) else {
            Logger.log("No data found in Keychain")
            return nil
        }
        guard let string = String(data: data, encoding: .utf8) else {
            Logger.log("Cannot convert data to string, deleting corrupted data")
            delete(service: service, account: account)
            return nil
        }
        return string
    }
    
    /// Удаляет данные из Keychain.
    /// - Parameters:
    ///   - service: Идентификатор сервиса.
    ///   - account: Идентификатор учетной записи.
    func delete(service: String, account: String) {
        do {
            try deleteThrows(service: service, account: account)
        } catch {
            Logger.log("Keychain delete error: \(error)")
        }
    }
    
    private func deleteThrows(service: String, account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
