//
//  DependencyContainer.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation
import SwiftData

// MARK: - Dependencies

@MainActor
protocol Dependencies {
    var config: AppConfiguration { get }
    var database: ModelContainer { get }

    func createRepository() throws -> any CurrencyRepository
    func createConverterScreen() async throws -> ConverterViewModel
    func networking() -> NetworkService
}

@MainActor
final class AppDependencies: Dependencies {

    let config: AppConfiguration
    let database: ModelContainer

    private var networkService: NetworkService?
    private var repository: (any CurrencyRepository)?
    private var conversionHistoryActor: ConversionHistoryActor?

    // MARK: - Shared Instance

    @MainActor
    private static var _shared: AppDependencies?

    @MainActor
    static var shared: AppDependencies {
        get throws {
            if let existing = _shared {
                return existing
            }
            let newInstance = try AppDependencies()
            _shared = newInstance
            return newInstance
        }
    }

    @MainActor
    static func setShared(_ dependencies: AppDependencies) {
        _shared = dependencies
    }

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

    func createRepository() throws -> any CurrencyRepository {
        if let existing = repository {
            return existing
        }

        let localStorage: any LocalCurrencyDataSource = CurrencyLocalDataSource(modelContainer: database)
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
        let actor = try historyActor()

        let conversionUseCase = CurrencyConversionUseCase(repository: repository)
        let loadCurrenciesUseCase = LoadCurrenciesUseCase(repository: repository)
        let saveConversionHistoryUseCase = SaveConversionHistoryUseCase(historyActor: actor)
        let numberFormatter = NumberFormatterService(locale: .current)
        let preferences = UserPreferences(defaults: .standard)

        return ConverterViewModel(
            conversionUseCase: conversionUseCase,
            loadCurrenciesUseCase: loadCurrenciesUseCase,
            saveConversionHistoryUseCase: saveConversionHistoryUseCase,
            numberFormatter: numberFormatter,
            preferences: preferences
        )
    }

    @MainActor
    func createHistoryScreen() throws -> HistoryViewModel {
        let actor = try historyActor()
        let historyUseCase = ConversionHistoryUseCase(historyActor: actor)
        return HistoryViewModel(historyUseCase: historyUseCase)
    }

    @MainActor
    func createConversionUseCase() throws -> any CurrencyConversionUseCaseProtocol {
        let repository = try createRepository()
        return CurrencyConversionUseCase(repository: repository)
    }

    @MainActor
    func createSaveHistoryUseCase() throws -> any SaveConversionHistoryUseCaseProtocol {
        let actor = try historyActor()
        return SaveConversionHistoryUseCase(historyActor: actor)
    }

    @MainActor
    private func historyActor() throws -> ConversionHistoryActor {
        if let conversionHistoryActor {
            return conversionHistoryActor
        }

        let actor = try ConversionHistoryActor(modelContainer: database)
        conversionHistoryActor = actor
        return actor
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
