//
//  KeychainHelper.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation
import Security

protocol KeychainManaging {
    func saveString(_ string: String, service: String, account: String)
    func readString(service: String, account: String) -> String?
    func delete(service: String, account: String)
    func initializeAPIKeyIfNeeded(service: String, account: String)
}

final class KeychainHelper: KeychainManaging {
    
    // MARK: - Public Properties
    
    static let shared = KeychainHelper()
    
    enum Constants {
        static let service = "com.yourapp.currencyconverter"
        static let account = "CurrencyAPIKey"
    }
    
    // MARK: - Private Properties
    
    private init() {}
    
    // MARK: - Public metod
    
    func initializeAPIKeyIfNeeded() {
        initializeAPIKeyIfNeeded(
            service: Constants.service,
            account: Constants.account
        )
    }
    
    func initializeAPIKeyIfNeeded(service: String, account: String) {
        // Пытаемся прочитать существующий ключ
        if let existingKey = readString(service: service, account: account) {
            // Проверяем, изменился ли ключ в конфиге
            guard let newKey = APIKeyLoader.loadAPIKey(),
                  !newKey.isEmpty,
                  newKey != existingKey else {
                return
            }
            
            // Обновляем ключ
            saveString(newKey, service: service, account: account)
            Logger.log("API-ключ обновлен в Keychain")
            return
        }
        
        // Ключа нет - загружаем и сохраняем
        guard let key = APIKeyLoader.loadAPIKey(),
              !key.isEmpty else {
            Logger.log("Ошибка: не удалось загрузить API-ключ из Config.plist")
            return
        }
        
        saveString(key, service: service, account: account)
        Logger.log("API-ключ сохранен в Keychain")
    }
    
    func saveString(_ string: String, service: String, account: String) {
        guard !string.isEmpty else {
            Logger.log("Предупреждение: попытка сохранить пустую строку в Keychain")
            return
        }
        
        guard let data = string.data(using: .utf8) else {
            Logger.log("Ошибка: не удалось преобразовать строку в данные")
            return
        }
        
        save(data, service: service, account: account)
    }
    
    func readString(service: String, account: String) -> String? {
        guard let data = read(service: service, account: account) else {
            return nil
        }
        
        guard let string = String(data: data, encoding: .utf8) else {
            // Данные повреждены - удаляем их
            delete(service: service, account: account)
            Logger.log("Предупреждение: поврежденные данные удалены из Keychain")
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
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            Logger.log("Ошибка удаления из Keychain: \(status)")
        }
    }
    
    // MARK: - Private metods
    
    private func save(_ data: Data, service: String, account: String) {
        // Сначала пытаемся обновить существующую запись
        if update(data, service: service, account: account) {
            return
        }
        
        // Если не нашли для обновления - создаем новую
        add(data, service: service, account: account)
    }
    
    private func update(_ data: Data, service: String, account: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )
        
        if status == errSecItemNotFound {
            return false
        }
        
        if status != errSecSuccess {
            Logger.log("Ошибка обновления в Keychain: \(status)")
        }
        
        return status == errSecSuccess
    }
    
    private func add(_ data: Data, service: String, account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        // Если запись уже существует - сначала удаляем, потом добавляем
        if status == errSecDuplicateItem {
            delete(service: service, account: account)
            
            // Пробуем добавить снова
            let retryStatus = SecItemAdd(query as CFDictionary, nil)
            if retryStatus != errSecSuccess {
                Logger.log("Ошибка добавления в Keychain после удаления дубликата: \(retryStatus)")
            }
        } else if status != errSecSuccess {
            Logger.log("Ошибка добавления в Keychain: \(status)")
        }
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
        
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                Logger.log("Ошибка чтения из Keychain: \(status)")
            }
            return nil
        }
        
        guard let data = result as? Data, !data.isEmpty else {
            Logger.log("Получены пустые или некорректные данные из Keychain")
            return nil
        }
        
        return data
    }
}
