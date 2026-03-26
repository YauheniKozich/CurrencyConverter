//
//  ErrorTypeMapper.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 26.03.26.
//

import Foundation

/// Компонент для классификации типов ошибок
enum ErrorType {
    case validation
    case configuration
    case network
    case unknown

    var isNonRecoverable: Bool {
        switch self {
        case .validation, .configuration: return true
        case .network, .unknown: return false
        }
    }

    static func from(_ error: String) -> ErrorType {
        let validationKeywords = ["Неверный формат", "Некорректная"]
        let configurationKeywords = ["Не указаны", "Конфигурация"]

        if validationKeywords.contains(where: error.contains) {
            return .validation
        } else if configurationKeywords.contains(where: error.contains) {
            return .configuration
        } else if error.contains("сеть") || error.contains("network") {
            return .network
        }
        return .unknown
    }
}
