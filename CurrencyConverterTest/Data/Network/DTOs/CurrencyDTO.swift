//
//  CurrencyDTO.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

// MARK: - Currencies List Response
// API: GET /v3/currencies
// Response: { "data": { "USD": { "code": "USD", "name": "...", ... } } }

struct CurrencyResponse: Decodable {
    let data: [String: Currency]
}

struct Currency: Decodable {
    let code: String
    let name: String
    
    init(code: String, name: String) {
        self.code = code
        self.name = name
    }

    // Поддержка разных имён полей для name
    enum CodingKeys: String, CodingKey {
        case code
        case name
        case displayName = "display_name"
        case title
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        code = try container.decode(String.self, forKey: .code)

        // Пробуем разные варианты имени
        if let nameValue = try container.decodeIfPresent(String.self, forKey: .name) {
            name = nameValue
        } else if let displayNameValue = try container.decodeIfPresent(String.self, forKey: .displayName) {
            name = displayNameValue
        } else if let titleValue = try container.decodeIfPresent(String.self, forKey: .title) {
            name = titleValue
        } else {
            name = code
        }
    }
}

// MARK: - Currency Conversion Response
// API: GET /v3/latest?base_currency=USD&currencies=EUR
// Response: { "data": { "EUR": { "code": "EUR", "value": 0.92 } }, "meta": { ... } }

struct CurrencyAPIResponse: Decodable {
    let data: [String: CurrencyValue]
    let meta: Meta?
    
    struct Meta: Decodable {
        let last_updated_at: String?
    }
    
    struct CurrencyValue: Decodable {
        let code: String
        let value: Double
    }
}

// MARK: - Currency Info Response

struct CurrencyInfoResponse: Decodable {
    let data: [String: CurrencyInfo]
}

struct CurrencyInfo: Decodable {
    let code: String
    let value: Double
}
