//
//  AppConfiguration.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

// Конфигурация приложения, загружаемая из файла Config.plist
struct AppConfiguration {
    
    // MARK: - Public Properties
    
    let apiKey: String
    let apiBaseURL: URL
    let cacheTTL: TimeInterval
    let networkTimeout: TimeInterval
    let keychainService: String
    let keychainAccount: String
    
    // MARK: - Initialization
    
    init() {
        guard let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: configPath) else {
            fatalError("Не удалось загрузить Config.plist")
        }
        
        guard let apiKey = config["CurrencyAPIKey"] as? String,
              !apiKey.isEmpty else {
            fatalError("API ключ не найден или пустой в Config.plist")
        }
        
        guard let apiBaseURLString = config["APIBaseURL"] as? String,
              let apiBaseURL = URL(string: apiBaseURLString) else {
            fatalError("Неверный API Base URL в Config.plist")
        }
        
        self.apiKey = apiKey
        self.apiBaseURL = apiBaseURL
        
        self.cacheTTL = config["CacheTTL"] as? TimeInterval ?? 3600
        self.networkTimeout = config["NetworkTimeout"] as? TimeInterval ?? 20
        
        self.keychainService = config["KeychainService"] as? String
        ?? "com.yourapp.currencyconverter"
        self.keychainAccount = config["KeychainAccount"] as? String
        ?? "CurrencyAPIKey"
    }
    
    // Инициализатор для тестирования
    init(apiKey: String,
         apiBaseURL: URL,
         cacheTTL: TimeInterval = 3600,
         networkTimeout: TimeInterval = 20,
         keychainService: String = "com.test.currencyconverter",
         keychainAccount: String = "CurrencyAPIKey") {
        self.apiKey = apiKey
        self.apiBaseURL = apiBaseURL
        self.cacheTTL = cacheTTL
        self.networkTimeout = networkTimeout
        self.keychainService = keychainService
        self.keychainAccount = keychainAccount
    }
}
