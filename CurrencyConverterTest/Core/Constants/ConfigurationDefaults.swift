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
    static let keychainService = Bundle.main.bundleIdentifier ?? "com.currencyconverter"
    static let keychainAccount = "CurrencyAPIKey"
}
