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

    private let formatter: NumberFormatter

    init(locale: Locale = .current) {
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
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return nil
        }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")

        // Input accepts either decimal separator; formatting still follows the locale.
        // Double parses the entire string, unlike NumberFormatter's partial parsing.
        let allowed = CharacterSet(charactersIn: "0123456789.+-eE")
        guard normalized.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              let value = Double(normalized),
              value.isFinite else {
            return nil
        }
        return value
    }
}
