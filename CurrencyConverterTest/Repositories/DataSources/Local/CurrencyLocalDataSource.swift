//
//  CurrencyLocalDataSource.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import SwiftUI
import SwiftData

final class CurrencyLocalDataSource {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func loadCachedRate(from: String, to: String) throws -> ExchangeRate? {
        let descriptor = FetchDescriptor<ExchangeRate>(predicate: #Predicate { $0.from == from && $0.to == to }, sortBy: [.init(\.timestamp, order: .reverse)])
        return try context.fetch(descriptor).first
    }

    func saveRate(from: String, to: String, rate: Double) throws {
        let cached = ExchangeRate(from: from, to: to, rate: rate)
        context.insert(cached)
        try context.save()
    }
}
