//
//  UserDefaultsProtocol.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

/// Протокол для абстракции UserDefaults, чтобы облегчить тестирование
protocol UserDefaultsProtocol {
    func string(forKey defaultName: String) -> String?
    func set(_ value: Any?, forKey defaultName: String)
}

/// Расширение UserDefaults для соответствия протоколу
extension UserDefaults: UserDefaultsProtocol {}
