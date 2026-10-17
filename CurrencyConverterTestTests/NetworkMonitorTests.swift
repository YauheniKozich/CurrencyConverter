//
//  NetworkMonitorTests.swift
//  CurrencyConverterTestTests
//
//  Created by Yauheni Kozich on 17.10.26.
//

import XCTest
@testable import CurrencyConverterTest

@MainActor
final class NetworkMonitorTests: XCTestCase {

    func testNetworkMonitor_sharedInstance() {
        let monitor = NetworkMonitor.shared
        XCTAssertNotNil(monitor)
    }

    func testNetworkMonitor_onRestorationRegistration() {
        let monitor = NetworkMonitor()
        var called = false
        monitor.onRestoration {
            called = true
        }
        XCTAssertFalse(called, "Restoration callback should not be invoked immediately")
    }

    func testAPIKeyStorage_convenienceInit() {
        let storage = APIKeyStorage()
        XCTAssertNotNil(storage)
    }
}
