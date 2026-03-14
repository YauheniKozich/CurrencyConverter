//
//  DependencyContainer.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation
import SwiftData

// MARK: - Dependencies

// Контейнер для управления зависимостями в приложении
protocol Dependencies {
    var config: AppConfiguration { get }
    var database: ModelContainer { get }

    func createRepository() throws -> CurrencyRepository
    @MainActor func createConverterScreen() async throws -> ConverterViewModel
    func networking() -> NetworkService
}

final class AppDependencies: Dependencies {

    let config: AppConfiguration
    let database: ModelContainer

    private var networkService: NetworkService?
    private var repository: CurrencyRepository?

    // MARK: - Initialization

    // Основной инициализатор для продакшена
    init() throws {
        config = try AppConfiguration()

        let schema = Schema([
            Conversion.self,
            ExchangeRate.self
        ])

        database = try ModelContainer(for: schema)
    }

    // Упрощенный инициализатор для тестов
    init(config: AppConfiguration, database: ModelContainer) {
        self.config = config
        self.database = database
    }

    // MARK: - Create Dependency

    func createRepository() throws -> CurrencyRepository {
        if let existing = repository {
            return existing
        }

        let localStorage: LocalCurrencyDataSource = CurrencyLocalDataSource(modelContainer: database)
        let networking = networking()

        let repo = try CurrencyAPIRepository(
            localDataSource: localStorage,
            networkService: networking,
            apiKey: config.apiKey,
            apiBaseURL: config.apiBaseURL,
            cacheTTL: config.cacheTTL
        )

        self.repository = repo
        return repo
    }

    @MainActor
    func createConverterScreen() async throws -> ConverterViewModel {
        let repository = try createRepository()
        let actor = try ConversionHistoryActor(modelContainer: database)

        let conversionUseCase = CurrencyConversionUseCase(repository: repository)
        let loadCurrenciesUseCase = LoadCurrenciesUseCase(repository: repository)
        let saveConversionHistoryUseCase = SaveConversionHistoryUseCase(historyActor: actor)

        return ConverterViewModel(
            conversionUseCase: conversionUseCase,
            loadCurrenciesUseCase: loadCurrenciesUseCase,
            saveConversionHistoryUseCase: saveConversionHistoryUseCase,
            numberFormatter: NumberFormatterService.shared
        )
    }

    func networking() -> NetworkService {
        if let existing = networkService {
            return existing
        }

        let service = NetworkService(timeout: config.networkTimeout)
        networkService = service
        return service
    }
}
