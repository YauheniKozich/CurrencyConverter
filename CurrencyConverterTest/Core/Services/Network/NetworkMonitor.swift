//
//  NetworkMonitor.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 17.10.26.
//

import Foundation
import Network
import SwiftUI

/// Протокол для отслеживания статуса сети
public protocol NetworkMonitoring: AnyObject, Sendable {
    @MainActor var isConnected: Bool { get }
    @MainActor var isExpensive: Bool { get }
}

/// Сервис мониторинга сети на базе NWPathMonitor
@Observable
@MainActor
public final class NetworkMonitor: NetworkMonitoring {

    public static let shared = NetworkMonitor()

    public private(set) var isConnected: Bool = true
    public private(set) var isExpensive: Bool = false

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.currencyconverter.networkmonitor")
    private var restorationHandler: (@MainActor () -> Void)?

    public init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        self.isConnected = monitor.currentPath.status == .satisfied
        start()
    }

    /// Регистрирует колбэк на восстановление подключения к сети
    public func onRestoration(_ handler: @escaping @MainActor () -> Void) {
        self.restorationHandler = handler
    }

    private func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasDisconnected = !self.isConnected
                let isNowConnected = (path.status == .satisfied)

                self.isConnected = isNowConnected
                self.isExpensive = path.isExpensive

                if wasDisconnected && isNowConnected {
                    Logger.log("Подключение к сети восстановлено", level: .info)
                    self.restorationHandler?()
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
