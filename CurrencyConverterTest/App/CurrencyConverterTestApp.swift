//
//  CurrencyConverterTestApp.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 19.05.25.
//

import SwiftUI
import SwiftData

@main
struct CurrencyConverterApp: App {
    let context: ModelContext

    init() {
        do {
            let container = try ModelContainer(for: Conversion.self, ExchangeRate.self)
            context = ModelContext(container)
        } catch {
            fatalError("Failed to create ModelContext: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ConverterView(context: context)
                .environment(\.modelContext, context)
        }
        .modelContainer(for: [Conversion.self, ExchangeRate.self])
    }
}
