//
//  CurrencyCacheManagerTests.swift
//  CurrencyConverterTestTests
//
//  Created by Yauheni Kozich on 14.03.26.
//

import XCTest
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
    
    override func tearDown() {
        cacheManager = nil
        mockDataSource = nil
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
        
        var loadCalled = false
        
        // Act
        let result = try await cacheManager.getCurrencies {
            loadCalled = true
            return expectedCurrencies
        }
        
        // Assert
        XCTAssertTrue(loadCalled, "Load block should be called")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result["GBP"]?.name, "British Pound")
    }
    
    func testGetCurrencies_concurrentLoads() async throws {
        // Arrange
        let expectedCurrencies: [String: Currency] = [
            "USD": Currency(code: "USD", name: "US Dollar")
        ]
        
        var loadCallCount = 0
        let loadBlock: () async throws -> [String: Currency] = {
            loadCallCount += 1
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms delay
            return expectedCurrencies
        }
        
        // Act - multiple concurrent calls
        async let first = cacheManager.getCurrencies(load: loadBlock)
        async let second = cacheManager.getCurrencies(load: loadBlock)
        async let third = cacheManager.getCurrencies(load: loadBlock)
        
        let results = try await (first, second, third)
        
        // Assert
        XCTAssertEqual(loadCallCount, 1, "Should only call load block once for concurrent calls")
        XCTAssertEqual(results.0.count, 1)
        XCTAssertEqual(results.1.count, 1)
        XCTAssertEqual(results.2.count, 1)
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
        cacheManager.invalidateCurrenciesCache()
        
        // Load again - should call load block
        var loadCalled = false
        _ = try await cacheManager.getCurrencies {
            loadCalled = true
            return expectedCurrencies
        }
        
        // Assert
        XCTAssertTrue(loadCalled, "Should call load block after invalidation")
    }
    
    // MARK: - Exchange Rate Cache Tests
    
    func testGetCachedRate_returnsValidRate() throws {
        // Arrange
        let expectedRate = 0.85
        mockDataSource.cachedRate = CachedRate(rate: expectedRate, timestamp: Date())
        
        // Act
        let result = try cacheManager.getCachedRate(from: "USD", to: "EUR")
        
        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, expectedRate, accuracy: 0.0001)
    }
    
    func testGetCachedRate_returnsNilWhenExpired() throws {
        // Arrange
        let expiredTimestamp = Date().addingTimeInterval(-2)  // 2 seconds ago
        mockDataSource.cachedRate = CachedRate(rate: 0.85, timestamp: expiredTimestamp)
        
        // Act
        let result = try cacheManager.getCachedRate(from: "USD", to: "EUR")
        
        // Assert
        XCTAssertNil(result, "Should return nil for expired cache")
    }
    
    func testGetCachedRate_returnsNilWhenNotFound() throws {
        // Arrange
        mockDataSource.cachedRate = nil
        
        // Act
        let result = try cacheManager.getCachedRate(from: "USD", to: "EUR")
        
        // Assert
        XCTAssertNil(result, "Should return nil when cache not found")
    }
    
    func testGetStaleCachedRate_returnsExpiredRate() throws {
        // Arrange
        let expiredRate = 0.80
        let expiredTimestamp = Date().addingTimeInterval(-2)  // 2 seconds ago
        mockDataSource.cachedRate = CachedRate(rate: expiredRate, timestamp: expiredTimestamp)
        
        // Act
        let result = try cacheManager.getStaleCachedRate(from: "USD", to: "EUR")
        
        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, expiredRate, accuracy: 0.0001, "Should return stale rate")
    }
    
    func testGetStaleCachedRate_returnsNilWhenNotFound() throws {
        // Arrange
        mockDataSource.cachedRate = nil
        
        // Act
        let result = try cacheManager.getStaleCachedRate(from: "USD", to: "EUR")
        
        // Assert
        XCTAssertNil(result, "Should return nil when no cache found")
    }
    
    func testSaveRate_savesToDataSource() {
        // Arrange
        let rate = 0.90
        
        // Act
        cacheManager.saveRate(from: "USD", to: "EUR", rate: rate)
        
        // Assert
        XCTAssertNotNil(mockDataSource.savedRate)
        XCTAssertEqual(mockDataSource.savedRate!.rate, rate, accuracy: 0.0001)
        XCTAssertEqual(mockDataSource.savedRate!.from, "USD")
        XCTAssertEqual(mockDataSource.savedRate!.to, "EUR")
    }
    
    func testSaveRate_handlesSaveFailure() {
        // Arrange
        mockDataSource.shouldFailOnSave = true
        
        // Act & Assert - should not crash
        cacheManager.saveRate(from: "USD", to: "EUR", rate: 0.90)
    }
}

// MARK: - Mock Currency Local DataSource

final class MockCurrencyLocalDataSource: LocalCurrencyDataSource {
    var cachedRate: CachedRate?
    var savedRate: (from: String, to: String, rate: Double)?
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
}
