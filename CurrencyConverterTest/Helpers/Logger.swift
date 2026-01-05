//
//  Logger.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 26.05.25.
//

import Foundation

final class Logger {
    static func log(_ message: String) {
#if DEBUG
        print("\(message)")
#endif
    }
}
