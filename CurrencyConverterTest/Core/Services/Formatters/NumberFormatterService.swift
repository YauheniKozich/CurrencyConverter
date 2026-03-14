//
//  NumberFormatterService.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

protocol NumberFormatting {
    func format(_ value: Double, decimals: Int) -> String
    func parse(_ string: String) -> Double?
}

final class NumberFormatterService: NumberFormatting {

    // MARK: - Shared Instance

    static let shared = NumberFormatterService()

    // MARK: - Private Properties

    private let formatter: NumberFormatter

    // MARK: - Initialization

    private init() {
        formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.usesGroupingSeparator = false
    }

    // For testing only
    init(locale: Locale) {
        formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.usesGroupingSeparator = false
    }

    // MARK: - Public Methods

    func format(_ value: Double, decimals: Int = 2) -> String {
        formatter.maximumFractionDigits = decimals
        formatter.minimumFractionDigits = decimals

        guard let result = formatter.string(from: NSNumber(value: value)) else {
            let format = "%.\(decimals)f"
            return String(format: format, value)
        }

        return result
    }

    func parse(_ string: String) -> Double? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            return nil
        }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")

        return formatter.number(from: normalized)?.doubleValue
    }
}
