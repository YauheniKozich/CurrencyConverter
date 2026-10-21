//
//  AppError.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

// MARK: - App Error

enum AppError: LocalizedError {
    // MARK: - Configuration (Critical)
    case configurationError(message: String)
    
    // MARK: - Network (Recoverable)
    case networkUnavailable
    case networkTimeout
    case serverError(statusCode: Int, message: String?)

    static func serverError(statusCode: Int) -> AppError {
        .serverError(statusCode: statusCode, message: nil)
    }
    
    // MARK: - Data (Recoverable)
    case dataNotFound
    case invalidDataFormat(reason: String)
    
    // MARK: - Validation (Non-recoverable)
    case validationError(message: String)
    
    // MARK: - Storage (Recoverable)
    case storageError(message: String)
    
    // MARK: - Unknown (Recoverable)
    case unknown(any Error)
}

// MARK: - User-Friendly Messages

extension AppError {
    var errorDescription: String? {
        switch self {
        case .configurationError:
            return String(localized: "Ошибка конфигурации приложения")
        case .networkUnavailable:
            return String(localized: "Нет подключения к интернету")
        case .networkTimeout:
            return String(localized: "Превышено время ожидания ответа")
        case .serverError(let code, _):
            switch code {
            case 401:
                return String(localized: "Неверный или неактивный API-ключ")
            case 403:
                return String(localized: "Доступ к API запрещен")
            case 422:
                return String(localized: "Некорректные параметры запроса")
            case 429:
                return String(localized: "Превышен лимит запросов к CurrencyAPI")
            case 500...599:
                return String(localized: "Сервер CurrencyAPI временно недоступен")
            default:
                return String(localized: "Ошибка сервера: код \(code)")
            }
        case .dataNotFound:
            return String(localized: "Данные не найдены")
        case .invalidDataFormat:
            return String(localized: "Неверный формат данных")
        case .validationError(let message):
            return message
        case .storageError:
            return String(localized: "Ошибка сохранения данных")
        case .unknown:
            return String(localized: "Произошла ошибка. Попробуйте снова.")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .configurationError:
            return String(localized: "Проверьте настройки приложения")
        case .networkUnavailable, .networkTimeout:
            return String(localized: "Проверьте подключение к интернету и попробуйте снова")
        case .serverError(let code, _):
            switch code {
            case 401, 403:
                return String(localized: "Проверьте правильность введенного API-ключа в настройках")
            case 429:
                return String(localized: "Подождите обновления квоты запросов или используйте другой API-ключ")
            default:
                return String(localized: "Попробуйте позже")
            }
        case .dataNotFound, .invalidDataFormat:
            return String(localized: "Обратитесь в службу поддержки")
        case .validationError:
            return String(localized: "Исправьте ошибку и повторите попытку")
        case .storageError:
            return String(localized: "Освободите место и попробуйте снова")
        case .unknown:
            return String(localized: "Попробуйте позже")
        }
    }
    
    var failureReason: String? {
        // Технические детали для логирования
        switch self {
        case .configurationError(let message):
            return "Configuration: \(message)"
        case .serverError(let code, let message):
            if let message {
                return "HTTP \(code): \(message)"
            }
            return "HTTP Status Code: \(code)"
        case .invalidDataFormat(let reason):
            return "Format error: \(reason)"
        case .validationError(let message):
            return "Validation: \(message)"
        case .storageError(let message):
            return "Storage: \(message)"
        case .unknown(let error):
            return "Unknown: \(error.localizedDescription)"
        default:
            return nil
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .networkUnavailable, .networkTimeout, .unknown:
            return true
        case .serverError(let code, _):
            return code == 0 || code == 408 || code == 429 || (500...599).contains(code)
        case .configurationError, .dataNotFound, .invalidDataFormat, .validationError, .storageError:
            return false
        }
    }
}
