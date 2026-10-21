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
                "Конвертируй валюту с помощью \(.applicationName)",
                "Переведи валюту с помощью \(.applicationName)",
                "Конвертируй \(\.$fromCurrency) с помощью \(.applicationName)",
                "Convert currency with \(.applicationName)",
                "Convert \(\.$fromCurrency) with \(.applicationName)"
            ],
            shortTitle: "Конвертация валюты",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}
