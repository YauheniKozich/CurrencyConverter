//
//  CurrencyHelper.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 17.10.26.
//

import Foundation

// MARK: - Currency Flag Helper

public enum CurrencyFlagHelper: Sendable {

    /// Предоставляет флаг эмодзи для кода валюты (ISO 4217)
    public static func flag(for currencyCode: String) -> String {
        let code = currencyCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Исключения и специальные региональные союзы / валюты
        switch code {
        case "EUR": return "🇪🇺"
        case "USD": return "🇺🇸"
        case "GBP": return "🇬🇧"
        case "BTC": return "₿"
        case "ETH": return "Ξ"
        case "XAU": return "🪙" // Золото
        case "XAG": return "🪙" // Серебро
        case "ANG": return "🇨🇼" // Нидерландский антильский гульден (Кюрасао)
        case "XCD": return "🇦🇮" // Восточно-карибский доллар
        case "XOF", "XAF": return "🌍" // Западно- и Центральноафриканский франк
        case "XPF": return "🇵🇫" // Французский тихоокеанский франк
        default:
            break
        }

        // Стандартное преобразование: первые 2 буквы валюты ISO 4217 -> ISO 3166-1 alpha-2 код страны
        let countryCode = String(code.prefix(2))
        guard countryCode.count == 2 else { return "🌐" }

        return emojiFlag(countryCode: countryCode)
    }

    /// Преобразует двухбуквенный ISO-код страны в флаг-эмодзи
    private static func emojiFlag(countryCode: String) -> String {
        let base: UInt32 = 127397
        var flag = ""
        for scalar in countryCode.unicodeScalars {
            if scalar.value >= 65 && scalar.value <= 90 { // 'A'...'Z'
                if let regional = UnicodeScalar(base + scalar.value) {
                    flag.unicodeScalars.append(regional)
                }
            }
        }
        return flag.count == 1 ? flag : "🌐"
    }
}

// MARK: - Currency Item Model

public struct CurrencyItem: Identifiable, Hashable, Sendable {
    public var id: String { code }
    public let code: String
    public let name: String
    public let flag: String

    public init(code: String, customName: String? = nil) {
        let trimmed = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.code = trimmed
        self.flag = CurrencyFlagHelper.flag(for: trimmed)

        if let customName, !customName.isEmpty, customName != trimmed {
            self.name = customName
        } else if let localized = Locale.current.localizedString(forCurrencyCode: trimmed) {
            self.name = localized.capitalized
        } else {
            self.name = trimmed
        }
    }
}
