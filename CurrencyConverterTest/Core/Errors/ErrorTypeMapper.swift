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
    case data
    case storage
    case unknown

    var isNonRecoverable: Bool {
        switch self {
        case .validation, .configuration, .data, .storage: return true
        case .network, .unknown: return false
        }
    }

    static func from(_ error: AppError) -> ErrorType {
        switch error {
        case .validationError:
            return .validation
        case .configurationError:
            return .configuration
        case .networkUnavailable, .networkTimeout, .serverError:
            return .network
        case .dataNotFound, .invalidDataFormat:
            return .data
        case .storageError:
            return .storage
        case .unknown:
            return .unknown
        }
    }
}
