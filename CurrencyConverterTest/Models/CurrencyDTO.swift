//
//  CurrencyDTO.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

struct CurrencyResponse: Decodable {
    let data: [String: Currency]
}

struct Currency: Decodable {
    let name: String
    let code: String
}

struct CurrencyAPIResponse: Decodable {
    let meta: Meta
    let data: [String: CurrencyValue]
    
    struct Meta: Decodable {
        let last_updated_at: String
    }
    
    struct CurrencyValue: Decodable {
        let code: String
        let value: Double
    }
}

struct CurrencyInfoResponse: Decodable {
    let data: [String: CurrencyInfo]
}

struct CurrencyInfo: Decodable {
    let code: String
    let value: Double
}
