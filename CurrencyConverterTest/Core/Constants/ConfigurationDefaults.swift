//
//  ConfigurationDefaults.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 14.03.26.
//

import Foundation

/// Константы конфигурации по умолчанию
enum ConfigurationDefaults {
    static let cacheTTL: TimeInterval = 3600          // 1 hour
    static let networkTimeout: TimeInterval = 30      // 30 seconds
    static let networkResourceTimeoutMultiplier: TimeInterval = 2
    static let urlCacheMemoryCapacity = 10 * 1024 * 1024
    static let urlCacheDiskCapacity = 50 * 1024 * 1024
    static let keychainService: String = {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let configuredService = config["KeychainService"] as? String,
              !configuredService.isEmpty else {
            return Bundle.main.bundleIdentifier ?? "com.currencyconverter"
        }
        return configuredService
    }()
    static let keychainAccount = "CurrencyAPIKey"
    static let keychainAccessGroup = "TLP4S46XK2.qwerty.CurrencyConverterTest"
    static let maxHistoryEntries: Int = 100
    static let defaultBaseURL = URL(string: "https://api.currencyapi.com/")!
}
