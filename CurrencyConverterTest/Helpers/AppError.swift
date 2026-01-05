//
//  AppError.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

// Основные ошибки приложения
enum AppError: LocalizedError {
    case configurationError(String)
    case networkError(Error)
    case decodingError(Error)
    case dataError(String)
    case validationError(String)
    case repositoryError(String)
    
    var errorDescription: String? {
        switch self {
        case .configurationError(let message):
            return "Конфигурация: \(message)"
        case .networkError(let error):
            return "Сеть: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Данные: \(error.localizedDescription)"
        case .dataError(let message):
            return "Данные: \(message)"
        case .validationError(let message):
            return "Валидация: \(message)"
        case .repositoryError(let message):
            return "Хранилище: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .configurationError:
            return "Проверьте настройки"
        case .networkError:
            return "Проверьте интернет и попробуйте снова"
        case .decodingError:
            return "Проблема с форматом данных"
        case .dataError:
            return "Проверьте данные"
        case .validationError:
            return "Исправьте данные и повторите"
        case .repositoryError:
            return "Попробуйте позже или обратитесь в поддержку"
        }
    }
}

final class ErrorHandler {
    
    static let shared = ErrorHandler()
    
    private init() {}
    
    /// Преобразует любую ошибку в AppError
    func handle(_ error: Error) -> AppError {
        // Если уже наша ошибка - возвращаем как есть
        if let appError = error as? AppError {
            return appError
        }
        
        // Сетевые ошибки
        if let urlError = error as? URLError {
            return .networkError(urlError)
        }
        
        // Ошибки декодирования
        if let decodingError = error as? DecodingError {
            return .decodingError(decodingError)
        }
        
        // Конвертируем в NSError для проверки домена
        let nsError = error as NSError
        
        // Ошибки CurrencyAPI
        if nsError.domain == "CurrencyAPI" {
            return .dataError(nsError.localizedDescription)
        }
        
        // Ошибки CoreData
        if nsError.domain == "NSCocoaErrorDomain" {
            return .repositoryError("Ошибка базы данных")
        }
        
        // Все остальное
        return .repositoryError(error.localizedDescription)
    }
    
    // Логирует ошибку
    func logError(_ error: Error, context: String = "") {
        let appError = handle(error)
        
        var logMessage = "Ошибка: \(appError.localizedDescription)"
        if !context.isEmpty {
            logMessage += " [\(context)]"
        }
        
        if let suggestion = appError.recoverySuggestion {
            logMessage += "\nРекомендация: \(suggestion)"
        }
        
        Logger.log(logMessage)
    }
    
    // Показывает ошибку пользователю (для реального проекта)
    func prepareAlert(for error: Error) -> (title: String, message: String) {
        let appError = handle(error)
        
        var message = appError.localizedDescription
        
        if let suggestion = appError.recoverySuggestion {
            message += "\n\n\(suggestion)"
        }
        
        return ("Ошибка", message)
    }
    
    // Дополнительный метод для более точной обработки сетевых ошибок
    func handleNetworkError(_ error: Error, endpoint: String? = nil) -> AppError {
        let nsError = error as NSError
        
        var context = ""
        if let endpoint = endpoint {
            context = " (\(endpoint))"
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError(error)
            case .timedOut:
                return .networkError(error)
            case .badURL, .unsupportedURL:
                return .dataError("Неверный URL адрес\(context)")
            case .cannotFindHost, .cannotConnectToHost:
                return .networkError(error)
            default:
                return .networkError(error)
            }
        }
        
        // Если это NSError с HTTP статусом
        if nsError.domain == NSURLErrorDomain {
            return .networkError(error)
        }
        
        return .networkError(error)
    }
}
