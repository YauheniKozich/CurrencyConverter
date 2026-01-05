//
//  DependencyContainer.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation
import SwiftData

// Контейнер для управления зависимостями в приложении
protocol Dependencies {
    var config: AppConfiguration { get }
    var database: ModelContainer { get }
    var dbContext: ModelContext { get }
    
    func createRepository() throws -> CurrencyRepository
    @MainActor func createConverterScreen() throws -> ConverterViewModel
    func networking() -> CurrencyNetworking
}

final class AppDependencies: Dependencies {
    
    let config: AppConfiguration
    let database: ModelContainer
    let dbContext: ModelContext
    
    private var networkService: CurrencyNetworking?
    private var keychainService: APIKeyProviding?
    
    // MARK: - Initialization
    
    // Основной инициализатор для продакшена
    init() throws {
        config = AppConfiguration()
        
        let schema = Schema([
            Conversion.self,
            ExchangeRate.self
        ])
        
        database = try ModelContainer(for: schema)
        dbContext = ModelContext(database)
    }
    
    // Упрощенный инициализатор для тестов
    init(config: AppConfiguration,
         database: ModelContainer,
         context: ModelContext) {
        self.config = config
        self.database = database
        self.dbContext = context
    }
    
    // MARK: - Create dependoncy
    
    func createRepository() throws -> CurrencyRepository {
        let localStorage = CurrencyLocalDataSource(context: dbContext)
        let networking = networking()
        let keychain = keychainProvider()
        
        return try CurrencyAPIRepository(
            context: dbContext,
            localDataSource: localStorage,
            networkService: networking,
            apiKeyProvider: keychain,
            apiKey: config.apiKey,
            apiBaseURL: config.apiBaseURL,
            cacheTTL: config.cacheTTL
        )
    }
    
    @MainActor
    func createConverterScreen() throws -> ConverterViewModel {
        let repository = try createRepository()
        let formatter = NumberFormatterService()
        
        return ConverterViewModel(
            repository: repository,
            numberFormatter: formatter,
            userDefaults: UserDefaults.standard as UserDefaultsProtocol
        )
    }
    
    func networking() -> CurrencyNetworking {
        // Используем кэшированный сервис, если есть
        if let existing = networkService {
            return existing
        }
        
        let session = createSession()
        let service = NetworkService(session: session)
        
        networkService = service
        return service
    }
    
    // MARK: - Helper methods
    
    private func keychainProvider() -> APIKeyProviding {
        if let existing = keychainService {
            return existing
        }
        
        let provider = KeychainAPIKeyProvider(
            service: config.keychainService,
            account: config.keychainAccount
        )
        
        keychainService = provider
        return provider
    }
    
    private func createSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        
        config.timeoutIntervalForRequest = self.config.networkTimeout
        config.timeoutIntervalForResource = self.config.networkTimeout * 2
        
        config.httpAdditionalHeaders = [
            "Accept": "application/json"
        ]
        
        // Для отладки можно добавить хост
        if let host = self.config.apiBaseURL.host {
            config.httpAdditionalHeaders?["Alt-Used"] = host
        }
        
        return URLSession(configuration: config)
    }
}
