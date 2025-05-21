//
//  CurrencyConverterTestApp.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 19.05.25.
//

import SwiftUI

@main
struct CurrencyConverterApp: App {

    var body: some Scene {
        WindowGroup {
            ConverterView()
        }
        .modelContainer(for: [Conversion.self, ExchangeRate.self])
    }
}
