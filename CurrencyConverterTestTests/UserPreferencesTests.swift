//
//  UserPreferencesTests.swift
//  CurrencyConverterTestTests
//
//  Created by Yauheni Kozich on 17.10.26.
//

import XCTest
@testable import CurrencyConverterTest

@MainActor
final class UserPreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var userDefaultsSuiteName: String!
    private var preferences: UserPreferences!

    override func setUp() async throws {
        userDefaultsSuiteName = "test.preferences.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: userDefaultsSuiteName)!
        preferences = UserPreferences(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: userDefaultsSuiteName)
        defaults = nil
        preferences = nil
    }

    func testInitialDefaultValues() {
        XCTAssertEqual(preferences.fromCurrency, "USD")
        XCTAssertEqual(preferences.toCurrency, "RUB")
        XCTAssertTrue(preferences.favoriteCurrencies.contains("USD"))
        XCTAssertTrue(preferences.favoriteCurrencies.contains("EUR"))
        XCTAssertTrue(preferences.isFavorite(currency: "USD"))
    }

    func testUpdateCurrencies() {
        preferences.fromCurrency = "EUR"
        preferences.toCurrency = "GBP"

        XCTAssertEqual(preferences.fromCurrency, "EUR")
        XCTAssertEqual(preferences.toCurrency, "GBP")

        // Recreate with same defaults to test persistence
        let newPreferencesInstance = UserPreferences(defaults: defaults)
        XCTAssertEqual(newPreferencesInstance.fromCurrency, "EUR")
        XCTAssertEqual(newPreferencesInstance.toCurrency, "GBP")
    }

    func testToggleFavorite_removesAndAdds() {
        XCTAssertTrue(preferences.isFavorite(currency: "USD"))

        // Remove USD
        preferences.toggleFavorite(currency: "USD")
        XCTAssertFalse(preferences.isFavorite(currency: "USD"))
        XCTAssertFalse(preferences.favoriteCurrencies.contains("USD"))

        // Add back USD
        preferences.toggleFavorite(currency: "USD")
        XCTAssertTrue(preferences.isFavorite(currency: "USD"))
        XCTAssertTrue(preferences.favoriteCurrencies.contains("USD"))

        // Add a brand new currency
        XCTAssertFalse(preferences.isFavorite(currency: "BTC"))
        preferences.toggleFavorite(currency: "BTC")
        XCTAssertTrue(preferences.isFavorite(currency: "BTC"))
    }

    func testRestoreDefaults() {
        preferences.fromCurrency = "JPY"
        preferences.toCurrency = "CAD"
        preferences.favoriteCurrencies = ["JPY"]

        preferences.restoreDefaults()

        XCTAssertEqual(preferences.fromCurrency, "USD")
        XCTAssertEqual(preferences.toCurrency, "RUB")
        XCTAssertEqual(preferences.favoriteCurrencies, UserPreferences.defaultFavorites)
    }
}
