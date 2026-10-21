//
//  CurrencyCacheManager.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 14.03.26.
//

import Foundation
import SwiftData

/// Менеджер кэширования валютных курсов
actor CurrencyCacheManager {

    private let localDataSource: any LocalCurrencyDataSource
    private let cacheTTL: TimeInterval

    private var cachedCurrencies: [String: Currency]?
    private var cachedCurrenciesUpdatedAt: Date?
    private var currenciesLoadTask: Task<Void, Never>?
    private var currenciesLoadID: UUID?
    private var currencyConsumers: [UUID: CheckedContinuation<[String: Currency], any Error>] = [:]
    var activeCurrencyConsumerCount: Int { currencyConsumers.count }
    private var ratesInvalidatedAt: Date?

    init(
        localDataSource: any LocalCurrencyDataSource,
        cacheTTL: TimeInterval = ConfigurationDefaults.cacheTTL
    ) {
        self.localDataSource = localDataSource
        self.cacheTTL = cacheTTL
    }

    func getCurrencies(
        load: @escaping @Sendable () async throws -> [String: Currency],
        forceRefresh: Bool = false
    ) async throws -> [String: Currency] {
        try Task.checkCancellation()
        if forceRefresh { invalidateCurrenciesCache() }
        if let cached = cachedCurrencies, let date = cachedCurrenciesUpdatedAt, isFresh(date) {
            return cached
        }

        let consumerID = UUID()
        let currencies: [String: Currency] = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Currency], any Error>) in
                // Cancellation can arrive between entering the handler and registration.
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                currencyConsumers[consumerID] = continuation
                guard currenciesLoadTask == nil else { return }
                let requestID = UUID()
                currenciesLoadID = requestID
                currenciesLoadTask = Task {
                    do {
                        let result = try await loadCurrencies(
                            load: load, forceRefresh: forceRefresh, requestID: requestID
                        )
                        finishCurrencyLoad(requestID: requestID, result: .success(result))
                    } catch {
                        finishCurrencyLoad(requestID: requestID, result: .failure(error))
                    }
                }
            }
        } onCancel: {
            // A bounded actor message; it never waits for the shared network task.
            Task { await self.cancelCurrencyConsumer(consumerID) }
        }
        try Task.checkCancellation()
        return currencies
    }

    func invalidateCurrenciesCache() {
        cancelCurrencyLoad()
        cachedCurrencies = nil
        cachedCurrenciesUpdatedAt = nil
    }

    private func cancelCurrencyConsumer(_ id: UUID) {
        guard let continuation = currencyConsumers.removeValue(forKey: id) else { return }
        continuation.resume(throwing: CancellationError())
        if currencyConsumers.isEmpty {
            currenciesLoadTask?.cancel()
            currenciesLoadTask = nil
            currenciesLoadID = nil
        }
    }

    private func cancelCurrencyLoad() {
        currenciesLoadTask?.cancel()
        currenciesLoadTask = nil
        currenciesLoadID = nil
        let consumers = currencyConsumers
        currencyConsumers.removeAll()
        for continuation in consumers.values {
            continuation.resume(throwing: CancellationError())
        }
    }

    private func finishCurrencyLoad(
        requestID: UUID, result: Result<[String: Currency], any Error>
    ) {
        guard currenciesLoadID == requestID else { return }
        currenciesLoadTask = nil
        currenciesLoadID = nil
        let consumers = currencyConsumers
        currencyConsumers.removeAll()
        for continuation in consumers.values { continuation.resume(with: result) }
    }

    private func checkCurrencyLoad(_ requestID: UUID) throws {
        try Task.checkCancellation()
        guard currenciesLoadID == requestID else { throw CancellationError() }
    }

    private func loadCurrencies(
        load: @Sendable () async throws -> [String: Currency],
        forceRefresh: Bool,
        requestID: UUID
    ) async throws -> [String: Currency] {
        // Disk lookup, network, fallback and disk save belong to the same in-flight request.
        if !forceRefresh {
            let disk = try? await localDataSource.loadCachedCurrencyList()
            try checkCurrencyLoad(requestID)
            if let disk, !disk.currencies.isEmpty, isFresh(disk.updatedAt) {
                cachedCurrencies = disk.currencies
                cachedCurrenciesUpdatedAt = disk.updatedAt
                return disk.currencies
            }
        }

        let currencies: [String: Currency]
        do {
            currencies = try await load()
        } catch {
            try checkCurrencyLoad(requestID)
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw CancellationError()
            }
            if error is CancellationError { throw CancellationError() }
            if let networkError = error as? NetworkError, !networkError.appError.isRecoverable {
                throw error
            }
            let disk = try? await localDataSource.loadCachedCurrencies()
            try checkCurrencyLoad(requestID)
            guard let disk, !disk.isEmpty else { throw error }
            cachedCurrencies = disk
            cachedCurrenciesUpdatedAt = .distantPast
            return disk
        }

        try checkCurrencyLoad(requestID)
        let updatedAt = Date()
        // Keep ownership through the save; cancellation/invalidation may occur at this await.
        try? await localDataSource.saveCachedCurrencies(currencies)
        try checkCurrencyLoad(requestID)
        cachedCurrencies = currencies
        cachedCurrenciesUpdatedAt = updatedAt
        return currencies
    }

    func getCachedRate(from: String, to: String) async throws -> Double? {
        guard let cached = try await localDataSource.loadCachedRate(from: from, to: to),
              cached.rate.isFinite, cached.rate > 0,
              isFresh(cached.timestamp),
              ratesInvalidatedAt.map({ cached.timestamp >= $0 }) ?? true else {
            return nil
        }

        Logger.log("Используем кэшированный курс \(from)/\(to)", level: .debug)
        return cached.rate
    }

    func getStaleCachedRate(from: String, to: String) async throws -> Double? {
        guard let cached = try? await localDataSource.loadCachedRate(from: from, to: to),
              cached.rate.isFinite, cached.rate > 0 else {
            return nil
        }

        Logger.log("Используем устаревший кэш \(from)/\(to) как fallback", level: .warning)
        return cached.rate
    }

    func invalidateRatesCache() {
        // Keep persisted rates available as stale fallback if the refresh fails.
        ratesInvalidatedAt = .now
    }

    func saveRate(from: String, to: String, rate: Double) async {
        do {
            try await localDataSource.saveRate(from: from, to: to, rate: rate)
            Logger.log("Курс сохранен в кэш", level: .debug)
        } catch {
            Logger.log("Не удалось сохранить курс в кэш: \(error)", level: .error)
        }
    }

    private func isFresh(_ date: Date) -> Bool {
        let age = Date().timeIntervalSince(date)
        return age >= 0 && age < cacheTTL
    }
}
