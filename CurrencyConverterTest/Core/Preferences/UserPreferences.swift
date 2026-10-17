//
//  UserPreferences.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 26.03.26.
//

import Foundation

// MARK: - User Preferences Protocol

/// Протокол для управления пользовательскими настройками валют
@MainActor
protocol UserPreferencesProtocol: AnyObject {
    var fromCurrency: String { get set }
    var toCurrency: String { get set }
    var favoriteCurrencies: [String] { get set }

    func isFavorite(currency: String) -> Bool
    func toggleFavorite(currency: String)
    func restoreDefaults()
}

// MARK: - User Preferences Implementation

/// Компонент для работы с пользовательскими настройками
@MainActor
final class UserPreferences: UserPreferencesProtocol {

    private let defaults: UserDefaults

    static let defaultFavorites: [String] = [
        "USD", "EUR", "GBP", "JPY", "CHF", "CNY", "CAD", "AUD", "RUB"
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var fromCurrency: String {
        get {
            defaults.string(forKey: "fromCurrency") ?? "USD"
        }
        set {
            guard newValue != fromCurrency else { return }
            defaults.set(newValue, forKey: "fromCurrency")
        }
    }

    var toCurrency: String {
        get {
            defaults.string(forKey: "toCurrency") ?? "RUB"
        }
        set {
            guard newValue != toCurrency else { return }
            defaults.set(newValue, forKey: "toCurrency")
        }
    }

    var favoriteCurrencies: [String] {
        get {
            defaults.stringArray(forKey: "favoriteCurrencies") ?? Self.defaultFavorites
        }
        set {
            defaults.set(newValue, forKey: "favoriteCurrencies")
        }
    }

    func isFavorite(currency: String) -> Bool {
        favoriteCurrencies.contains(currency)
    }

    func toggleFavorite(currency: String) {
        var current = favoriteCurrencies
        if let index = current.firstIndex(of: currency) {
            current.remove(at: index)
        } else {
            current.append(currency)
        }
        favoriteCurrencies = current
    }

    func restoreDefaults() {
        fromCurrency = "USD"
        toCurrency = "RUB"
        favoriteCurrencies = Self.defaultFavorites
    }
}
