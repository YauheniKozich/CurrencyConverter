//
//  AssemblyViewModelFactory.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation
import SwiftData

/// Фабрика для создания экземпляров ViewModel
enum ViewModelFactory {
    @MainActor static func makeConverterViewModel(context: ModelContext) -> ConverterViewModel {
        let localDataSource = CurrencyLocalDataSource(context: context)
        let networkService = NetworkService()
        let apiKeyProvider = KeychainAPIKeyProvider()
        do {
            let repository = try CurrencyAPIRepository(
                context: context,
                localDataSource: localDataSource,
                networkService: networkService,
                apiKeyProvider: apiKeyProvider
            )
            return ConverterViewModel(repository: repository)
        } catch {
            fatalError("Не удалось создать CurrencyAPIRepository: \(error)")
        }
    }
}
