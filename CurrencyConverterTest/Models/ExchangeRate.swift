//
//  ExchangeRate.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import SwiftUI
import SwiftData

@Model
class ExchangeRate: Identifiable {
    var id: UUID
    var from: String
    var to: String
    var rate: Double
    var timestamp: Date
    
    init(from: String, to: String, rate: Double, timestamp: Date = .now) {
        self.id = UUID()
        self.from = from
        self.to = to
        self.rate = rate
        self.timestamp = timestamp
    }
}
