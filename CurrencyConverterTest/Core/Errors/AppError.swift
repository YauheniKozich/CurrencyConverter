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
            return "Ошибка конфигурации приложения"
        case .networkUnavailable:
            return "Нет подключения к интернету"
        case .networkTimeout:
            return "Превышено время ожидания ответа"
        case .serverError(let code, let customMessage):
            if let customMessage, !customMessage.isEmpty {
                return customMessage
            }
            switch code {
            case 401:
                return "Неверный или неактивный API-ключ"
            case 403:
                return "Доступ к API запрещен"
            case 422:
                return "Некорректные параметры запроса"
            case 429:
                return "Превышен лимит запросов к CurrencyAPI"
            case 500...599:
                return "Сервер CurrencyAPI временно недоступен"
            default:
                return "Ошибка сервера: код \(code)"
            }
        case .dataNotFound:
            return "Данные не найдены"
        case .invalidDataFormat:
            return "Неверный формат данных"
        case .validationError(let message):
            return message
        case .storageError:
            return "Ошибка сохранения данных"
        case .unknown:
            return "Произошла ошибка. Попробуйте снова."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .configurationError:
            return "Проверьте настройки приложения"
        case .networkUnavailable, .networkTimeout:
            return "Проверьте подключение к интернету и попробуйте снова"
        case .serverError(let code, _):
            switch code {
            case 401, 403:
                return "Проверьте правильность введенного API-ключа в настройках"
            case 429:
                return "Подождите обновления квоты запросов или используйте другой API-ключ"
            default:
                return "Попробуйте позже"
            }
        case .dataNotFound, .invalidDataFormat:
            return "Обратитесь в службу поддержки"
        case .validationError:
            return "Исправьте ошибку и повторите попытку"
        case .storageError:
            return "Освободите место и попробуйте снова"
        case .unknown:
            return "Попробуйте позже"
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
        case .networkUnavailable, .networkTimeout, .serverError, .unknown:
            return true
        case .configurationError, .dataNotFound, .invalidDataFormat, .validationError, .storageError:
            return false
        }
    }
}
