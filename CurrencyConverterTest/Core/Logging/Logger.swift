//
//  Logger.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 26.05.25.
//

import Foundation
import os

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

final class Logger {

    private static let logger = os.Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.currencyconverter",
        category: "App"
    )

    static func log(
        _ message: String,
        level: LogLevel = .info
    ) {
        switch level {
        case .debug:
            logger.debug("\(message)")
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .error:
            logger.error("\(message)")
        }
    }
}
