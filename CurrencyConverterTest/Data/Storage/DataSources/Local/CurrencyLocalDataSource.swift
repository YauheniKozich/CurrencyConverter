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

struct CachedCurrencyList: Sendable {
    let currencies: [String: Currency]
    let updatedAt: Date
}

/// The model executor owns the context; only Sendable snapshots leave this actor.
actor CurrencyLocalDataSource: ModelActor {

    private struct CurrencyCacheFile: Codable {
        let currencies: [String: Currency]
        let updatedAt: Date
    }

    nonisolated let modelContainer: ModelContainer
    nonisolated let modelExecutor: any ModelExecutor
    private let cacheDirectoryURL: URL?

    init(modelContainer: ModelContainer, cacheDirectoryURL: URL? = nil) {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.cacheDirectoryURL = cacheDirectoryURL
    }

    func loadCachedRate(from: String, to: String) async throws -> CachedRate? {
        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate { $0.from == from && $0.to == to },
            sortBy: [.init(\.timestamp, order: .reverse)]
        )
        guard let cached = try modelContext.fetch(descriptor).first else {
            return nil
        }
        return CachedRate(rate: cached.rate, timestamp: cached.timestamp)
    }

    func saveRate(from: String, to: String, rate: Double) async throws {
        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate { $0.from == from && $0.to == to },
            sortBy: [.init(\.timestamp, order: .reverse)]
        )
        let existing = try modelContext.fetch(descriptor)
        if let current = existing.first {
            current.rate = rate
            current.timestamp = Date()
            for duplicate in existing.dropFirst() {
                modelContext.delete(duplicate)
            }
        } else {
            let cached = ExchangeRate(from: from, to: to, rate: rate)
            modelContext.insert(cached)
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    // MARK: - Currencies Persistence

    private var currenciesCacheURL: URL? {
        let directory = cacheDirectoryURL ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
        return directory?.appendingPathComponent("cached_currencies.json")
    }

    func loadCachedCurrencies() async throws -> [String: Currency]? {
        try await loadCachedCurrencyList()?.currencies
    }

    func loadCachedCurrencyList() async throws -> CachedCurrencyList? {
        guard let cache = try loadCurrencyCacheFile() else { return nil }
        return CachedCurrencyList(currencies: cache.currencies, updatedAt: cache.updatedAt)
    }

    func saveCachedCurrencies(_ currencies: [String: Currency]) async throws {
        try Task.checkCancellation()
        guard let url = currenciesCacheURL else { return }
        let directory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let cache = CurrencyCacheFile(currencies: currencies, updatedAt: Date())
        let data = try JSONEncoder().encode(cache)
        try data.write(to: url, options: .atomic)
    }

    private func loadCurrencyCacheFile() throws -> CurrencyCacheFile? {
        guard let url = currenciesCacheURL, FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        if let cache = try? JSONDecoder().decode(CurrencyCacheFile.self, from: data) {
            return cache
        }

        // Previous releases stored only the dictionary. Keep it as stale offline data;
        // without a timestamp it must be refreshed before being treated as current.
        let legacyCurrencies = try JSONDecoder().decode([String: Currency].self, from: data)
        return CurrencyCacheFile(currencies: legacyCurrencies, updatedAt: .distantPast)
    }

    func clearCachedCurrencies() async throws {
        guard let url = currenciesCacheURL, FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
