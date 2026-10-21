//
//  KeychainReadResultTests.swift
//  CurrencyConverterTestTests
//
//  Created by Codex on 21.10.26.
//

import XCTest
import Security
@testable import CurrencyConverterTest

final class KeychainReadResultTests: XCTestCase {
    func testMissingLockedAndFailedReadsAreDistinct() {
        XCTAssertEqual(KeychainHelper.interpretReadResult(status: errSecItemNotFound, data: nil), .notFound)
        XCTAssertEqual(
            KeychainHelper.interpretReadResult(status: errSecInteractionNotAllowed, data: nil),
            .temporarilyUnavailable(errSecInteractionNotAllowed)
        )
        XCTAssertEqual(
            KeychainHelper.interpretReadResult(status: errSecNotAvailable, data: nil),
            .temporarilyUnavailable(errSecNotAvailable)
        )
        XCTAssertEqual(
            KeychainHelper.interpretReadResult(status: errSecMissingEntitlement, data: nil),
            .failure(errSecMissingEntitlement)
        )
    }

    func testSuccessfulReadRequiresValidNonemptyData() {
        XCTAssertEqual(KeychainHelper.interpretReadResult(status: errSecSuccess, data: Data("fixture".utf8)), .value("fixture"))
        XCTAssertEqual(KeychainHelper.interpretReadResult(status: errSecSuccess, data: Data()), .failure(errSecDecode))
        XCTAssertEqual(KeychainHelper.interpretReadResult(status: errSecSuccess, data: Data([0xff])), .failure(errSecDecode))
    }

    func testRealKeychainRoundTripUsesIsolatedService() {
        let helper = KeychainHelper()
        let service = "CurrencyConverterTest.tests." + UUID().uuidString
        let account = "read-result-fixture"
        defer { helper.delete(service: service, account: account) }
        XCTAssertEqual(helper.readStringResult(service: service, account: account), .notFound)
        XCTAssertTrue(helper.saveString("fixture", service: service, account: account))
        XCTAssertEqual(helper.readStringResult(service: service, account: account), .value("fixture"))
    }
}
