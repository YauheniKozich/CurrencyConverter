//
//  AssemblyViewModelFactory.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation
import SwiftData

enum ViewModelFactory {
    @MainActor static func makeConverterViewModel(context: ModelContext) -> ConverterViewModel {
        let repository = CurrencyAPIRepository(context: context)
        return ConverterViewModel(repository: repository)
    }
}
