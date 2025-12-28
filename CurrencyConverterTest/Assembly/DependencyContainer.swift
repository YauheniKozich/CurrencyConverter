//
//  DependencyContainer.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation
import SwiftData

/// Контейнер зависимостей для инверсии контроля
@MainActor
protocol DependencyContainerProtocol {
    var configuration: AppConfiguration { get }
    var modelContainer: ModelContainer { get }
    var modelContext: ModelContext { get }

    func makeCurrencyRepository() -> Result<CurrencyRepository, AppError>
    func makeConverterViewModel() -> Result<ConverterViewModel, AppError>
    func makeNetworkService() -> CurrencyNetworking
    func makeLocalDataSource(context: ModelContext) -> CurrencyLocalDataStoring
    func makeAPIKeyProvider() -> APIKeyProviding
}

/// Реализация контейнера зависимостей
final class DependencyContainer: DependencyContainerProtocol {
    let configuration: AppConfiguration
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    private var _networkService: CurrencyNetworking?
    private var _apiKeyProvider: APIKeyProviding?

    init(configuration: AppConfiguration = AppConfiguration()) throws {
        self.configuration = configuration

        let schema = Schema([Conversion.self, ExchangeRate.self])
        self.modelContainer = try ModelContainer(for: schema)
        self.modelContext = ModelContext(modelContainer)
    }

    // Для тестирования с in-memory контейнером
    init(configuration: AppConfiguration = AppConfiguration(),
         modelContainer: ModelContainer,
         modelContext: ModelContext) {
        self.configuration = configuration
        self.modelContainer = modelContainer
        self.modelContext = modelContext
    }

    func makeCurrencyRepository() -> Result<CurrencyRepository, AppError> {
        let localDataSource = makeLocalDataSource(context: modelContext)
        let networkService = makeNetworkService()
        let apiKeyProvider = makeAPIKeyProvider()

        do {
            let repository = try CurrencyAPIRepository(
                context: modelContext,
                localDataSource: localDataSource,
                networkService: networkService,
                apiKeyProvider: apiKeyProvider,
                apiKey: configuration.apiKey,
                apiBaseURL: configuration.apiBaseURL,
                cacheTTL: configuration.cacheTTL
            )
            return .success(repository)
        } catch {
            let appError = AppError.configurationError("Не удалось создать репозиторий: \(error.localizedDescription)")
            return .failure(appError)
        }
    }

    @MainActor func makeConverterViewModel() -> Result<ConverterViewModel, AppError> {
        let repositoryResult = makeCurrencyRepository()

        switch repositoryResult {
        case .success(let repository):
            let viewModel = ConverterViewModel(
                repository: repository,
                numberFormatter: makeNumberFormatter(),
                userDefaults: UserDefaults.standard
            )
            return .success(viewModel)
        case .failure(let error):
            return .failure(error)
        }
    }

    func makeNetworkService() -> CurrencyNetworking {
        if let networkService = _networkService {
            return networkService
        }

        let session = makeURLSession()
        let networkService = NetworkService(session: session)
        _networkService = networkService
        return networkService
    }

    func makeLocalDataSource(context: ModelContext) -> CurrencyLocalDataStoring {
        return CurrencyLocalDataSource(context: context)
    }

    func makeAPIKeyProvider() -> APIKeyProviding {
        if let apiKeyProvider = _apiKeyProvider {
            return apiKeyProvider
        }

        let apiKeyProvider = KeychainAPIKeyProvider(
            service: configuration.keychainService,
            account: configuration.keychainAccount
        )
        _apiKeyProvider = apiKeyProvider
        return apiKeyProvider
    }

    private func makeURLSession() -> URLSession {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = configuration.networkTimeout
        sessionConfig.timeoutIntervalForResource = configuration.networkTimeout * 2
        sessionConfig.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Alt-Used": "\(configuration.apiBaseURL.host ?? "api.currencyapi.com")"
        ]
        sessionConfig.multipathServiceType = .interactive
        return URLSession(configuration: sessionConfig)
    }

    private func makeNumberFormatter() -> NumberFormatting {
        return NumberFormatterService()
    }
}
