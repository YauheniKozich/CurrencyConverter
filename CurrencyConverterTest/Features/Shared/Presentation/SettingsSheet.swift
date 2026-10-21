//
//  SettingsSheet.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 17.10.26.
//

import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showAPIKeyInputSheet = false
    @State private var isRefreshing = false
    @State private var refreshTask: Task<Void, Never>?
    @State private var didSaveAPIKey = false

    let currenciesCount: Int
    let onRefreshCurrencies: () async -> Void
    var onAPIKeySaved: () -> Void = {}
    var refreshErrorMessage: String? = nil

    private let apiKeyStorage = APIKeyStorage()
    private let networkMonitor = NetworkMonitor.shared

    private var maskedAPIKey: String {
        guard let key = apiKeyStorage.load(), !key.isEmpty else {
            return String(localized: "Не задан")
        }
        if key.count <= 8 {
            return "••••••••"
        }
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        return "\(prefix)••••\(suffix)"
    }

    private var networkStatusText: String {
        String(localized: networkMonitor.isConnected ? "Онлайн" : "Офлайн")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("API Ключ")) {
                    HStack {
                        Text("Текущий ключ")
                        Spacer()
                        Text(maskedAPIKey)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Текущий API ключ: \(maskedAPIKey)")

                    Button {
                        showAPIKeyInputSheet = true
                    } label: {
                        Label("Изменить API-ключ", systemImage: "key.fill")
                    }
                    .accessibilityLabel("Изменить API ключ")
                    .accessibilityHint("Открывает окно для ввода нового ключа CurrencyAPI")
                }

                Section(header: Text("Кэш и данные")) {
                    HStack {
                        Text("Доступно валют")
                        Spacer()
                        Text("\(currenciesCount)")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Доступно валют в кэше: \(currenciesCount)")

                    HStack {
                        Text("Статус сети")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(networkMonitor.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(verbatim: networkStatusText)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Статус сети: \(networkStatusText)")

                    Button {
                        refreshCurrencies()
                    } label: {
                        HStack {
                            Label("Обновить курсы и валюты", systemImage: "arrow.clockwise")
                            Spacer()
                            if isRefreshing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!networkMonitor.isConnected || isRefreshing)
                    .accessibilityLabel("Обновить курсы и валюты")
                    .accessibilityHint("Запрашивает актуальный список валют и курсы с сервера")

                    if let refreshErrorMessage, !isRefreshing {
                        Text(verbatim: refreshErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section(header: Text("О приложении")) {
                    HStack {
                        Text("Версия")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)

                    Link(destination: URL(string: "https://currencyapi.com")!) {
                        HStack {
                            Label("Поставщик данных (CurrencyAPI)", systemImage: "arrow.up.right.square")
                            Spacer()
                        }
                    }
                    .accessibilityLabel("Перейти на сайт поставщика данных CurrencyAPI")
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") {
                        dismiss()
                    }
                    .accessibilityLabel("Закрыть настройки")
                }
            }
            .sheet(isPresented: $showAPIKeyInputSheet, onDismiss: {
                guard didSaveAPIKey else { return }
                didSaveAPIKey = false
                dismiss()
                onAPIKeySaved()
            }) {
                APIKeyInputSheet { _ in
                    // The child dismisses itself only after a successful save.
                    didSaveAPIKey = true
                }
            }
        }
        .onDisappear {
            refreshTask?.cancel()
        }
    }

    private func refreshCurrencies() {
        guard !isRefreshing, networkMonitor.isConnected else { return }
        isRefreshing = true
        refreshTask = Task {
            defer {
                isRefreshing = false
                refreshTask = nil
            }
            guard !Task.isCancelled else { return }
            await onRefreshCurrencies()
        }
    }
}
#Preview {
    SettingsSheet(
        currenciesCount: 154,
        onRefreshCurrencies: {}
    )
}

