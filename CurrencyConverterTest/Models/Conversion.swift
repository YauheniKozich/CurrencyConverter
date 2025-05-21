//
//  Conversion.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import SwiftData
import SwiftUI

@Model
class Conversion: Identifiable {
    var id: UUID
    var from: String
    var to: String
    var amount: Double
    var result: Double
    var rate: Double
    var date: Date
    
    init(from: String, to: String, amount: Double, result: Double, rate: Double, date: Date = .now) {
        self.id = UUID()
        self.from = from
        self.to = to
        self.amount = amount
        self.result = result
        self.rate = rate
        self.date = date
    }
}
