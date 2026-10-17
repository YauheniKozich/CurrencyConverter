//
//  CurrencyLocalDataSource.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation
import SwiftData

struct CachedRate: Sendable {
    let rate: Double
    let timestamp: Date
}

/// Safe to share because it is created for and accessed only by the
/// `CurrencyCacheManager` actor, which serializes every synchronous context access.
final class CurrencyLocalDataSource: @unchecked Sendable {

    private let context: ModelContext
    private let cacheDirectoryURL: URL?

    init(modelContainer: ModelContainer, cacheDirectoryURL: URL? = nil) {
        self.context = ModelContext(modelContainer)
        self.context.autosaveEnabled = false
        self.cacheDirectoryURL = cacheDirectoryURL
    }

    func loadCachedRate(from: String, to: String) throws -> CachedRate? {
        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate { $0.from == from && $0.to == to },
            sortBy: [.init(\.timestamp, order: .reverse)]
        )
        guard let cached = try context.fetch(descriptor).first else {
            return nil
        }
        return CachedRate(rate: cached.rate, timestamp: cached.timestamp)
    }

    func saveRate(from: String, to: String, rate: Double) throws {
        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate { $0.from == from && $0.to == to },
            sortBy: [.init(\.timestamp, order: .reverse)]
        )
        let existing = try context.fetch(descriptor)
        if let current = existing.first {
            current.rate = rate
            current.timestamp = Date()
            for duplicate in existing.dropFirst() {
                context.delete(duplicate)
            }
        } else {
            let cached = ExchangeRate(from: from, to: to, rate: rate)
            context.insert(cached)
        }
        try context.save()
    }

    // MARK: - Currencies Persistence

    private var currenciesCacheURL: URL? {
        let directory = cacheDirectoryURL ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
        return directory?.appendingPathComponent("cached_currencies.json")
    }

    func loadCachedCurrencies() throws -> [String: Currency]? {
        guard let url = currenciesCacheURL, FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([String: Currency].self, from: data)
    }

    func saveCachedCurrencies(_ currencies: [String: Currency]) throws {
        guard let url = currenciesCacheURL else { return }
        let directory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let data = try JSONEncoder().encode(currencies)
        try data.write(to: url, options: .atomic)
    }

    func clearCachedCurrencies() throws {
        guard let url = currenciesCacheURL, FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
