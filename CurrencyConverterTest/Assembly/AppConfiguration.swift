//
//  AppConfiguration.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

enum ConfigurationError: LocalizedError {
    case configFileNotFound
    case invalidAPIKey
    case invalidBaseURL

    var errorDescription: String? {
        switch self {
        case .configFileNotFound:
            return "Файл конфигурации не найден"
        case .invalidAPIKey:
            return "API ключ не найден или пустой"
        case .invalidBaseURL:
            return "Неверный базовый URL API"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .configFileNotFound:
            return "Проверьте наличие файла Config.plist в проекте"
        case .invalidAPIKey:
            return "Добавьте корректный API ключ в Config.plist или задайте CURRENCY_API_KEY в окружении схемы"
        case .invalidBaseURL:
            return "Проверьте правильность URL в Config.plist"
        }
    }
}

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

    init() throws {
        guard let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: configPath) else {
            throw ConfigurationError.configFileNotFound
        }

        guard let apiBaseURLString = config["APIBaseURL"] as? String,
              let apiBaseURL = URL(string: apiBaseURLString) else {
            throw ConfigurationError.invalidBaseURL
        }

        self.apiBaseURL = apiBaseURL

        self.cacheTTL = config["CacheTTL"] as? TimeInterval 
            ?? ConfigurationDefaults.cacheTTL
        self.networkTimeout = config["NetworkTimeout"] as? TimeInterval 
            ?? ConfigurationDefaults.networkTimeout

        self.keychainService = config["KeychainService"] as? String
        ?? ConfigurationDefaults.keychainService
        self.keychainAccount = config["KeychainAccount"] as? String
        ?? ConfigurationDefaults.keychainAccount

        // Загружаем API ключ через новый фасад
        let storage = APIKeyStorage(service: keychainService, account: keychainAccount)
        guard let apiKey = APIKeyLoader.loadAndStore(from: config, storage: storage) else {
            throw ConfigurationError.invalidAPIKey
        }

        self.apiKey = apiKey
    }

    // Инициализатор для тестирования
    init(apiKey: String,
         apiBaseURL: URL,
         cacheTTL: TimeInterval = ConfigurationDefaults.cacheTTL,
         networkTimeout: TimeInterval = ConfigurationDefaults.networkTimeout,
         keychainService: String = ConfigurationDefaults.keychainService,
         keychainAccount: String = ConfigurationDefaults.keychainAccount) throws {

        guard !apiKey.isEmpty else {
            throw ConfigurationError.invalidAPIKey
        }

        self.apiKey = apiKey
        self.apiBaseURL = apiBaseURL
        self.cacheTTL = cacheTTL
        self.networkTimeout = networkTimeout
        self.keychainService = keychainService
        self.keychainAccount = keychainAccount
    }
}
