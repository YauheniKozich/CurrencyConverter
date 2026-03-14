//
//  APIKeyLoader.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

/// Загрузчик API ключа — фасад для Source и Storage
enum APIKeyLoader {
    
    /// Загружает API ключ и сохраняет в Keychain
    /// - Parameters:
    ///   - config: Конфигурация из plist
    ///   - storage: Хранилище для сохранения
    /// - Returns: API ключ или nil если не найден
    static func loadAndStore(
        from config: NSDictionary,
        storage: APIKeyStorage
    ) -> String? {
        // 1. Пробуем загрузить из Source (environment/config)
        if let key = APIKeySource.load(from: config) {
            storage.save(key)
            return key
        }
        
        // 2. Пробуем загрузить из Keychain
        if let key = storage.load() {
            return key
        }
        
        Logger.log("Не удалось загрузить API ключ", level: .warning)
        return nil
    }
}
