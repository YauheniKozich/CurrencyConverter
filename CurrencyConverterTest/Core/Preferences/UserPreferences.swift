//
//  UserPreferences.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 26.03.26.
//

import Foundation

/// Компонент для работы с пользовательскими настройками
final class UserPreferences: @unchecked Sendable {

    private let defaults: UserDefaults

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

    func restoreDefaults() {
        fromCurrency = "USD"
        toCurrency = "RUB"
    }
}
