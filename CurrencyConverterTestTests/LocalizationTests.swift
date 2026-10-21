//
//  LocalizationTests.swift
//  CurrencyConverterTestTests
//
//  Created by Codex on 21.10.26.
//

import XCTest
@testable import CurrencyConverterTest

final class LocalizationTests: XCTestCase {
    func testValidationAndNetworkMessagesInBothLanguages() throws {
        let appBundle = Bundle(for: NumberFormatterService.self)
        let messages = [
            ("Неверный формат суммы", "Invalid amount format"),
            ("Некорректная сумма", "Invalid amount"),
            ("Нет подключения к интернету", "No internet connection"),
            ("Неверный или неактивный API-ключ", "Invalid or inactive API key"),
            ("Превышен лимит запросов к CurrencyAPI", "CurrencyAPI request limit exceeded"),
            ("Сервер CurrencyAPI временно недоступен", "The CurrencyAPI server is temporarily unavailable")
        ]
        for language in ["ru", "en"] {
            let path = try XCTUnwrap(appBundle.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            for (russian, english) in messages {
                XCTAssertEqual(
                    bundle.localizedString(forKey: russian, value: nil, table: "Localizable"),
                    language == "ru" ? russian : english
                )
            }
        }
    }
}
