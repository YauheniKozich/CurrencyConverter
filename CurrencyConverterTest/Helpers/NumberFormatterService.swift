//
//  NumberFormatterService.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

/// Протокол для форматирования чисел
protocol NumberFormatting {
    func formatDecimal(_ value: Double, maximumFractionDigits: Int) -> String
    func parseDecimal(_ string: String) -> Double?
}

/// Реализация сервиса форматирования чисел
final class NumberFormatterService: NumberFormatting {
    private let decimalFormatter: NumberFormatter
    private let inputFormatter: NumberFormatter

    init(locale: Locale = .current) {
        decimalFormatter = NumberFormatter()
        decimalFormatter.numberStyle = .decimal
        decimalFormatter.locale = locale

        inputFormatter = NumberFormatter()
        inputFormatter.numberStyle = .decimal
        // Используем POSIX локаль для надежного парсинга чисел
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        inputFormatter.allowsFloats = true
        inputFormatter.usesGroupingSeparator = false
    }

    func formatDecimal(_ value: Double, maximumFractionDigits: Int) -> String {
        decimalFormatter.maximumFractionDigits = maximumFractionDigits
        return decimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    func parseDecimal(_ string: String) -> Double? {
        return inputFormatter.number(from: string)?.doubleValue
    }
}
