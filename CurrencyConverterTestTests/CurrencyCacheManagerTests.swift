//
//  CurrencyCacheManagerTests.swift
//  CurrencyConverterTestTests
//
//  Created by Yauheni Kozich on 14.03.26.
//

import XCTest
import SwiftData
@testable import CurrencyConverterTest

@MainActor
final class CurrencyCacheManagerTests: XCTestCase {
    
    var cacheManager: CurrencyCacheManager!
    var mockDataSource: MockCurrencyLocalDataSource!
    
    override func setUp() async throws {
        mockDataSource = MockCurrencyLocalDataSource()
        cacheManager = CurrencyCacheManager(
            localDataSource: mockDataSource,
            cacheTTL: 1.0  // 1 second for testing
        )
    }
    
    override func tearDown() async throws {
        cacheManager = nil
        mockDataSource = nil
        try await super.tearDown()
    }
    

    func testFallbackRetainsInFlightOwnershipUntilCompletion() async throws {
        let started = expectation(description: "Fallback read started")
        let source = FallbackGateSource(started: started)
        let manager = CurrencyCacheManager(localDataSource: source)
        let first = Task {
            try await manager.getCurrencies { throw URLError(.notConnectedToInternet) }
        }
        await fulfillment(of: [started], timeout: 3)
        let second = Task {
            try await manager.getCurrencies { XCTFail("Fallback must coalesce"); return [:] }
        }
        do {
            try await waitForConsumers(2, manager: manager)
        } catch {
            await source.release()
            _ = await first.result
            _ = await second.result
            throw error
        }
        await source.release()
        let old = try await first.value
        let coalesced = try await second.value
        XCTAssertEqual(old["USD"]?.name, "Old")
        XCTAssertEqual(coalesced["USD"]?.name, "Old")
        let fresh = ["NOK": Currency(code: "NOK", name: "Fresh")]
        _ = try await manager.getCurrencies(load: { fresh }, forceRefresh: true)
        let cached = try await manager.getCurrencies { XCTFail("Fresh RAM cache lost"); return [:] }
        XCTAssertEqual(cached["NOK"]?.name, "Fresh")
    }


    private func waitForConsumers(_ count: Int, manager: CurrencyCacheManager) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while await manager.activeCurrencyConsumerCount != count {
            guard clock.now < deadline else {
                XCTFail("Consumers did not reach expected registration state")
                throw CancellationError()
            }
            await Task.yield()
        }
    }

    func testCancelledBeforeStartNeverLoads() async throws {
        let manager = CurrencyCacheManager(localDataSource: MockCurrencyLocalDataSource())
        let gate = StartGate()
        let request = Task {
            await gate.wait()
            return try await manager.getCurrencies { XCTFail("Cancelled request loaded"); return [:] }
        }
        request.cancel()
        await gate.open()
        do { _ = try await request.value; XCTFail("Expected cancellation") }
        catch is CancellationError {}
        let count = await manager.activeCurrencyConsumerCount
        XCTAssertEqual(count, 0)
    }

    func testCancellingOneConsumerKeepsSharedNetworkAndLastCancelStopsIt() async throws {
        let started = expectation(description: "Network started")
        let stopped = expectation(description: "Network cancelled")
        let firstFinished = expectation(description: "First consumer cancelled promptly")
        let secondFinished = expectation(description: "Last consumer cancelled promptly")
        let (stream, continuation) = AsyncThrowingStream<[String: Currency], any Error>.makeStream()
        continuation.onTermination = { _ in stopped.fulfill() }
        defer { continuation.finish() }
        let manager = CurrencyCacheManager(localDataSource: MockCurrencyLocalDataSource())
        let first = Task {
            defer { firstFinished.fulfill() }
            return try await manager.getCurrencies {
                started.fulfill()
                var iterator = stream.makeAsyncIterator()
                return try await iterator.next() ?? [:]
            }
        }
        await fulfillment(of: [started], timeout: 3)
        let second = Task {
            defer { secondFinished.fulfill() }
            return try await manager.getCurrencies { XCTFail("Duplicated shared load"); return [:] }
        }
        do {
            try await waitForConsumers(2, manager: manager)
        } catch {
            continuation.finish()
            _ = await first.result
            _ = await second.result
            throw error
        }
        first.cancel()
        first.cancel()
        let firstWait = await XCTWaiter.fulfillment(of: [firstFinished], timeout: 3)
        XCTAssertEqual(firstWait, .completed)
        if firstWait != .completed { continuation.finish() }
        do { _ = try await first.value; XCTFail("Expected cancellation") }
        catch is CancellationError {}
        let remaining = await manager.activeCurrencyConsumerCount
        XCTAssertEqual(remaining, 1)
        second.cancel()
        second.cancel()
        let secondWait = await XCTWaiter.fulfillment(of: [secondFinished], timeout: 3)
        XCTAssertEqual(secondWait, .completed)
        if secondWait != .completed { continuation.finish() }
        do { _ = try await second.value; XCTFail("Expected cancellation") }
        catch is CancellationError {}
        await fulfillment(of: [stopped], timeout: 3)
        let finalCount = await manager.activeCurrencyConsumerCount
        XCTAssertEqual(finalCount, 0)
        let recovered = try await manager.getCurrencies { ["NOK": Currency(code: "NOK", name: "Recovered")] }
        XCTAssertNotNil(recovered["NOK"])
    }

    func testCancelledFirstConsumerDoesNotPreventSecondSuccess() async throws {
        let manager = CurrencyCacheManager(localDataSource: MockCurrencyLocalDataSource())
        let network = CatalogGate()
        let first = Task { try await manager.getCurrencies { try await network.value() } }
        try await waitForConsumers(1, manager: manager)
        let second = Task {
            try await manager.getCurrencies { XCTFail("Duplicate load"); return [:] }
        }
        do {
            try await waitForConsumers(2, manager: manager)
        } catch {
            await network.finish()
            _ = await first.result
            _ = await second.result
            throw error
        }
        first.cancel()
        let cancelled = expectation(description: "Cancelled consumer completes before network")
        let observer = Task {
            _ = await first.result
            cancelled.fulfill()
        }
        let outcome = await XCTWaiter.fulfillment(of: [cancelled], timeout: 3)
        XCTAssertEqual(outcome, .completed)
        if outcome != .completed { await network.finish() }
        await observer.value
        do { _ = try await first.value; XCTFail("Expected cancellation") }
        catch is CancellationError {}
        await network.finish()
        let result = try await second.value
        XCTAssertNotNil(result["NOK"])
    }

    func testInvalidatedFallbackCannotPublishAfterFreshRefresh() async throws {
        let started = expectation(description: "Fallback suspended")
        let source = FallbackGateSource(started: started)
        let manager = CurrencyCacheManager(localDataSource: source)
        let first = Task { try await manager.getCurrencies { throw URLError(.notConnectedToInternet) } }
        await fulfillment(of: [started], timeout: 3)
        let fresh = ["NOK": Currency(code: "NOK", name: "Fresh")]
        _ = try await manager.getCurrencies(load: { fresh }, forceRefresh: true)
        await source.release()
        do { _ = try await first.value; XCTFail("Expected invalidation") }
        catch is CancellationError {}
        let cached = try await manager.getCurrencies { XCTFail("Fresh cache lost"); return [:] }
        XCTAssertEqual(cached["NOK"]?.name, "Fresh")
    }

    // MARK: - Currency List Cache Tests
    
    func testGetCurrencies_returnsCachedValue() async throws {
        // Arrange
        let expectedCurrencies: [String: Currency] = [
            "USD": Currency(code: "USD", name: "US Dollar"),
            "EUR": Currency(code: "EUR", name: "Euro")
        ]
        
        // First load - from network
        _ = try await cacheManager.getCurrencies {
            return expectedCurrencies
        }
        
        // Act - second load - from cache
        let result = try await cacheManager.getCurrencies {
            XCTFail("Should not call load block when cached")
            return [:]
        }
        
        // Assert
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["USD"]?.name, "US Dollar")
        XCTAssertEqual(result["EUR"]?.name, "Euro")
    }
    
    func testGetCurrencies_loadsFromNetwork() async throws {
        // Arrange
        let expectedCurrencies: [String: Currency] = [
            "GBP": Currency(code: "GBP", name: "British Pound")
        ]
        
        let tracker = CallTracker()
        
        // Act
        let result = try await cacheManager.getCurrencies {
            await tracker.call()
            return expectedCurrencies
        }
        
        // Assert
        let wasCalled = await tracker.wasCalled
        XCTAssertTrue(wasCalled, "Load block should be called")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result["GBP"]?.name, "British Pound")
    }
    
    func testGetCurrencies_concurrentLoads() async throws {
        // Arrange
        let expectedCurrencies: [String: Currency] = [
            "USD": Currency(code: "USD", name: "US Dollar")
        ]
        
        let tracker = CallTracker()
        let loadBlock: @Sendable () async throws -> [String: Currency] = {
            await tracker.call()
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms delay
            return expectedCurrencies
        }
        
        // Act - multiple concurrent calls
        let manager = cacheManager!
        async let first = manager.getCurrencies(load: loadBlock)
        async let second = manager.getCurrencies(load: loadBlock)
        async let third = manager.getCurrencies(load: loadBlock)
        
        let (firstResult, secondResult, thirdResult) = try await (first, second, third)
        
        // Assert
        let callCount = await tracker.count
        XCTAssertEqual(callCount, 1, "Should only call load block once for concurrent calls")
        XCTAssertEqual(firstResult.count, 1)
        XCTAssertEqual(secondResult.count, 1)
        XCTAssertEqual(thirdResult.count, 1)
    }
    
    func testInvalidationRejectsSuspendedDiskLookup() async throws {
        let started = expectation(description: "Disk lookup suspended")
        let source = SuspendedDiskSource(started: started)
        let manager = CurrencyCacheManager(localDataSource: source)
        let request = Task { try await manager.getCurrencies { [:] } }
        let result = await XCTWaiter.fulfillment(of: [started], timeout: 3)
        XCTAssertEqual(result, .completed)
        await manager.invalidateCurrenciesCache()
        await source.resumeLookup()
        do {
            _ = try await request.value
            XCTFail("An invalidated lookup must not restore old disk data")
        } catch is CancellationError {
            // Expected: the generation changed while disk access was suspended.
        }
    }

    func testInvalidateCurrenciesCache() async throws {
        // Arrange
        let expectedCurrencies: [String: Currency] = [
            "USD": Currency(code: "USD", name: "US Dollar")
        ]
        
        // First load
        _ = try await cacheManager.getCurrencies {
            return expectedCurrencies
        }

        // Act - invalidate
        await cacheManager.invalidateCurrenciesCache()

        // Load again - should call load block
        let tracker = CallTracker()
        _ = try await cacheManager.getCurrencies {
            await tracker.call()
            return expectedCurrencies
        }

        // Assert
        let wasCalled = await tracker.wasCalled
        XCTAssertTrue(wasCalled, "Should call load block after invalidation")
    }

    // MARK: - Exchange Rate Cache Tests

    func testGetCachedRate_returnsValidRate() async throws {
        // Arrange
        let expectedRate = 0.85
        mockDataSource.cachedRate = CachedRate(rate: expectedRate, timestamp: Date())

        // Act
        let result = try await cacheManager.getCachedRate(from: "USD", to: "EUR")

        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, expectedRate, accuracy: 0.0001)
    }

    func testGetCachedRate_returnsNilWhenExpired() async throws {
        // Arrange
        let expiredTimestamp = Date().addingTimeInterval(-2)  // 2 seconds ago
        mockDataSource.cachedRate = CachedRate(rate: 0.85, timestamp: expiredTimestamp)

        // Act
        let result = try await cacheManager.getCachedRate(from: "USD", to: "EUR")
        
        // Assert
        XCTAssertNil(result, "Should return nil for expired cache")
    }
    
    func testGetCachedRate_returnsNilWhenNotFound() async throws {
        // Arrange
        mockDataSource.cachedRate = nil

        // Act
        let result = try await cacheManager.getCachedRate(from: "USD", to: "EUR")

        // Assert
        XCTAssertNil(result, "Should return nil when cache not found")
    }

    func testGetStaleCachedRate_returnsExpiredRate() async throws {
        // Arrange
        let expiredRate = 0.80
        let expiredTimestamp = Date().addingTimeInterval(-2)  // 2 seconds ago
        mockDataSource.cachedRate = CachedRate(rate: expiredRate, timestamp: expiredTimestamp)

        // Act
        let result = try await cacheManager.getStaleCachedRate(from: "USD", to: "EUR")

        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, expiredRate, accuracy: 0.0001, "Should return stale rate")
    }

    func testGetStaleCachedRate_returnsNilWhenNotFound() async throws {
        // Arrange
        mockDataSource.cachedRate = nil

        // Act
        let result = try await cacheManager.getStaleCachedRate(from: "USD", to: "EUR")

        // Assert
        XCTAssertNil(result, "Should return nil when no cache found")
    }
    
    func testSaveRate_savesToDataSource() async {
        // Arrange
        let rate = 0.90

        // Act
        await cacheManager.saveRate(from: "USD", to: "EUR", rate: rate)

        // Assert
        XCTAssertNotNil(mockDataSource.savedRate)
        XCTAssertEqual(mockDataSource.savedRate!.rate, rate, accuracy: 0.0001)
        XCTAssertEqual(mockDataSource.savedRate!.from, "USD")
        XCTAssertEqual(mockDataSource.savedRate!.to, "EUR")
    }

    func testSaveRate_handlesSaveFailure() async {
        // Arrange
        mockDataSource.shouldFailOnSave = true

        // Act & Assert - should not crash
        await cacheManager.saveRate(from: "USD", to: "EUR", rate: 0.90)
    }

    func testGetCurrencies_usesDiskCache_whenRAMCacheEmpty() async throws {
        // Arrange
        let diskCurrencies: [String: Currency] = [
            "GBP": Currency(code: "GBP", name: "British Pound")
        ]
        mockDataSource.cachedCurrencies = diskCurrencies

        // Act
        let result = try await cacheManager.getCurrencies {
            XCTFail("Should not call load block when disk cache is available")
            return [:]
        }

        // Assert
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result["GBP"]?.name, "British Pound")
    }

    func testGetCurrencies_fallsBackToDiskCache_whenNetworkFails() async throws {
        // Arrange
        let diskCurrencies: [String: Currency] = [
            "JPY": Currency(code: "JPY", name: "Japanese Yen")
        ]
        mockDataSource.cachedCurrencies = diskCurrencies

        // Act - network fails with forceRefresh
        let result = try await cacheManager.getCurrencies(load: {
            throw URLError(.notConnectedToInternet)
        }, forceRefresh: true)

        // Assert - gracefully fallback to disk
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result["JPY"]?.name, "Japanese Yen")
    }

    func testCurrencyLocalDataSource_saveRate_upsertDoesNotDuplicate() async throws {
        let schema = Schema([ExchangeRate.self, Conversion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let dataSource = CurrencyLocalDataSource(modelContainer: container)

        // Act - first save
        try await dataSource.saveRate(from: "USD", to: "EUR", rate: 0.92)
        let firstFetch = try await dataSource.loadCachedRate(from: "USD", to: "EUR")
        XCTAssertEqual(firstFetch?.rate, 0.92)

        // Act - second save for the same pair with updated rate
        try await dataSource.saveRate(from: "USD", to: "EUR", rate: 0.95)
        let secondFetch = try await dataSource.loadCachedRate(from: "USD", to: "EUR")
        XCTAssertEqual(secondFetch?.rate, 0.95)

        // Assert - verify only 1 row exists in SwiftData
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ExchangeRate>()
        let allRates = try context.fetch(descriptor)
        XCTAssertEqual(allRates.count, 1)
        XCTAssertEqual(allRates.first?.rate, 0.95)
    }
}

// MARK: - Test Helpers

private actor CallTracker {
    var count: Int = 0
    var wasCalled: Bool = false

    func call() {
        count += 1
        wasCalled = true
    }
}

// MARK: - Mock Currency Local DataSource

final class MockCurrencyLocalDataSource: LocalCurrencyDataSource, @unchecked Sendable {
    var cachedRate: CachedRate?
    var savedRate: (from: String, to: String, rate: Double)?
    var cachedCurrencies: [String: Currency]?
    var savedCurrencies: [String: Currency]?
    var shouldFailOnSave = false
    
    func loadCachedRate(from: String, to: String) throws -> CachedRate? {
        return cachedRate
    }
    
    func saveRate(from: String, to: String, rate: Double) throws {
        if shouldFailOnSave {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Save failed"])
        }
        savedRate = (from, to, rate)
    }

    func loadCachedCurrencies() throws -> [String: Currency]? {
        return cachedCurrencies
    }

    func saveCachedCurrencies(_ currencies: [String: Currency]) throws {
        savedCurrencies = currencies
    }
}

private actor SuspendedDiskSource: LocalCurrencyDataSource {
    let started: XCTestExpectation
    private var continuation: CheckedContinuation<Void, Never>?

    init(started: XCTestExpectation) { self.started = started }

    func loadCachedCurrencyList() async throws -> CachedCurrencyList? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started.fulfill()
        }
        return CachedCurrencyList(currencies: ["USD": Currency(code: "USD", name: "Dollar")], updatedAt: .now)
    }

    func resumeLookup() {
        continuation?.resume()
        continuation = nil
    }

    func loadCachedRate(from: String, to: String) async throws -> CachedRate? { nil }
    func saveRate(from: String, to: String, rate: Double) async throws {}
}

private actor FallbackGateSource: LocalCurrencyDataSource {
    let started: XCTestExpectation
    private var continuation: CheckedContinuation<[String: Currency]?, Never>?
    init(started: XCTestExpectation) { self.started = started }
    func loadCachedCurrencyList() async throws -> CachedCurrencyList? { nil }
    func loadCachedCurrencies() async throws -> [String: Currency]? {
        await withCheckedContinuation { continuation = $0; started.fulfill() }
    }
    func release() {
        continuation?.resume(returning: ["USD": Currency(code: "USD", name: "Old")])
        continuation = nil
    }
    func loadCachedRate(from: String, to: String) async throws -> CachedRate? { nil }
    func saveRate(from: String, to: String, rate: Double) async throws {}
}

private actor StartGate {
    private var isOpen = false
    private var continuation: CheckedContinuation<Void, Never>?
    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func open() { isOpen = true; continuation?.resume(); continuation = nil }
}

private actor CatalogGate {
    private var completed = false
    private var continuation: CheckedContinuation<[String: Currency], any Error>?
    func value() async throws -> [String: Currency] {
        if completed { return ["NOK": Currency(code: "NOK", name: "Fresh")] }
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func finish() {
        completed = true
        continuation?.resume(returning: ["NOK": Currency(code: "NOK", name: "Fresh")])
        continuation = nil
    }
}
