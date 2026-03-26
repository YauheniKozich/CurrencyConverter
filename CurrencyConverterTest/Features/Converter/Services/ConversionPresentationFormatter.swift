//
//  ConversionPresentationFormatter.swift
//  CurrencyConverterTest
//
//  Created by Codex on 26.03.26.
//

import Foundation

protocol ConversionFormatting {
    func formatAmount(_ value: Double) -> String
    func formatResult(_ value: Double) -> String
    func formatRate(_ value: Double) -> String
}

final class ConversionPresentationFormatter: ConversionFormatting {
    private enum Formatting {
        static let resultFractionDigits = 2
        static let rateFractionDigits = 4
    }

    private let numberFormatter: any NumberFormatting

    init(numberFormatter: any NumberFormatting) {
        self.numberFormatter = numberFormatter
    }

    func formatAmount(_ value: Double) -> String {
        numberFormatter.format(value, decimals: Formatting.resultFractionDigits)
    }

    func formatResult(_ value: Double) -> String {
        numberFormatter.format(value, decimals: Formatting.resultFractionDigits)
    }

    func formatRate(_ value: Double) -> String {
        numberFormatter.format(value, decimals: Formatting.rateFractionDigits)
    }
}
