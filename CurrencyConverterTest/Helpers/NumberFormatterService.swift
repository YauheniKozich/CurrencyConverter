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

// Сервис для работы с числами
final class NumberFormatterService: NumberFormatting {
    
    private let formatter: NumberFormatter
    
    init() {
        formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.usesGroupingSeparator = false
    }
    
    func format(_ value: Double, decimals: Int = 2) -> String {
        formatter.maximumFractionDigits = decimals
        formatter.minimumFractionDigits = decimals
        
        guard let result = formatter.string(from: NSNumber(value: value)) else {
            let format = "%.\(decimals)f"
            return String(format: format, value)
        }
        
        return result
    }
    
    /// Парсит строку в число
    func parse(_ string: String) -> Double? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        
        guard !trimmed.isEmpty else {
            return nil
        }
        
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        
        return formatter.number(from: normalized)?.doubleValue
    }
}

// MARK: - Extension for NumberFormatterService

extension NumberFormatterService {
    
    // Форматирует денежную сумму
    func formatCurrency(_ amount: Double, currencyCode: String? = nil) -> String {
        let formatted = format(amount, decimals: 2)
        
        guard let code = currencyCode, !code.isEmpty else {
            return formatted
        }
        
        return "\(formatted) \(code)"
    }
    
    // Форматирует процент
    func formatPercent(_ value: Double) -> String {
        let formatted = format(value, decimals: 2)
        return "\(formatted)%"
    }
}
