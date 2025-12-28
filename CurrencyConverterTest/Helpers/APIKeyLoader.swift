//
//  APIKeyLoader.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

enum APIKeyLoader {
    static func loadAPIKey() -> String? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let apiKey = config["CurrencyAPIKey"] as? String else {
            Logger.log("Не удалось загрузить API-ключ из Config.plist")
            return nil
        }
        return apiKey
    }
}
