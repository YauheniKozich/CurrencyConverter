//
//  CurrencyAppShortcuts.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 17.10.26.
//

import AppIntents

struct CurrencyAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ConvertCurrencyIntent(),
            phrases: [
                "Конвертируй валюту в \(.applicationName)",
                "Переведи валюту в \(.applicationName)",
                "Конвертируй \(\.$fromCurrency) в \(.applicationName)",
                "Convert currency in \(.applicationName)",
                "Convert \(\.$fromCurrency) in \(.applicationName)"
            ],
            shortTitle: "Конвертация валюты",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}
