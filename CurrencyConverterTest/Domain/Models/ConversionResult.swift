//
//  ConversionResult.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 14.03.26.
//

import Foundation

/// Результат конвертации валют
struct ConversionResult: Sendable, Equatable {
    let result: Double
    let rate: Double
    let isStaleRate: Bool

    init(result: Double, rate: Double, isStaleRate: Bool = false) {
        self.result = result
        self.rate = rate
        self.isStaleRate = isStaleRate
    }
}
