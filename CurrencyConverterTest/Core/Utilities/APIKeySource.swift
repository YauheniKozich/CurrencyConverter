//
//  APIKeySource.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 14.03.26.
//

import Foundation

/// Источник загрузки API ключа
enum APIKeySource {
    private static let environmentKey = "CURRENCY_API_KEY"
    private static let configKey = "CurrencyAPIKey"
    private static let placeholderValues: Set<String> = ["YOUR_API_KEY", "YOUR-API-KEY"]
    
    /// Загружает API ключ из доступных источников
    /// - Parameter config: Конфигурация из plist
    /// - Returns: API ключ или nil если не найден
    static func load(from config: NSDictionary) -> String? {
        // 1. Пробуем загрузить из переменных окружения
        if let key = loadFromEnvironment() {
            Logger.log("API ключ загружен из переменных окружения", level: .debug)
            return key
        }
        
        // 2. Пробуем загрузить из конфигурации
        if let key = loadFromConfig(config) {
            Logger.log("API ключ загружен из Config.plist", level: .debug)
            return key
        }
        
        Logger.log("API ключ не найден в окружении или конфигурации", level: .warning)
        return nil
    }
    
    // MARK: - Private Methods
    
    private static func loadFromEnvironment() -> String? {
        guard let envValue = ProcessInfo.processInfo.environment[environmentKey] else {
            return nil
        }
        
        let trimmed = envValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        
        return trimmed
    }
    
    private static func loadFromConfig(_ config: NSDictionary) -> String? {
        guard let configValue = config[configKey] as? String else {
            return nil
        }
        
        let trimmed = configValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            Logger.log("API ключ в Config.plist пустой", level: .warning)
            return nil
        }
        
        guard !placeholderValues.contains(trimmed) else {
            Logger.log("API ключ в Config.plist содержит плейсхолдер", level: .warning)
            return nil
        }
        
        return trimmed
    }
}
