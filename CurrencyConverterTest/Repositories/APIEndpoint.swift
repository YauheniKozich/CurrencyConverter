//
//  APIEndpoint.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

enum APIEndpoint {
    static func currencies(key: String) -> URL? {
        URL(string: "https://api.currencyapi.com/v3/currencies?apikey=\(key)")
    }
    static func latest(from: String, to: String, key: String) -> URL? {
        URL(string: "https://api.currencyapi.com/v3/latest?apikey=\(key)&base_currency=\(from)&currencies=\(to)")
    }
}
