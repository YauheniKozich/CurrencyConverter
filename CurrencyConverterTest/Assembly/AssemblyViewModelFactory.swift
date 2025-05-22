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
        guard let repository = CurrencyAPIRepository(context: context) else {
            fatalError("Не удалось создать CurrencyAPIRepository")
        }
        return ConverterViewModel(repository: repository)
    }
}
