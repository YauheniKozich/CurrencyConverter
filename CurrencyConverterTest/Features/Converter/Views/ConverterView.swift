//
//  ConverterView.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import SwiftUI

struct ConverterView: View {
    @ObservedObject var viewModel: ConverterViewModel
    @State private var showErrorAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Выбор валют")) {
                    Picker("Из", selection: $viewModel.fromCurrency) {
                        ForEach(viewModel.currencies, id: \.self) { Text($0) }
                    }
                    Picker("В", selection: $viewModel.toCurrency) {
                        ForEach(viewModel.currencies, id: \.self) { Text($0) }
                    }
                }
                .disabled(viewModel.currencies.isEmpty)

                Section(header: Text("Сумма")) {
                    TextField("Введите сумму", text: .init(
                        get: { viewModel.amount },
                        set: { viewModel.setAmount($0) }
                    ))
                    .keyboardType(.decimalPad)
                    .submitLabel(.done)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(viewModel.errorMessage == "Неверный формат суммы" ? Color.red : Color.clear, lineWidth: 1)
                    )
                }

                if let error = viewModel.currenciesLoadingError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    }
                }

                Button("Конвертировать") {
                    viewModel.convert()
                }
                .disabled(viewModel.amount.isEmpty || viewModel.currencies.isEmpty)

                if !viewModel.result.isEmpty {
                    Section(header: Text("Результат")) {
                        Text("\(viewModel.amount) \(viewModel.fromCurrency) = \(viewModel.result) \(viewModel.toCurrency)")
                        Text("Курс: \(viewModel.rate)")
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

                NavigationLink("История") {
                    HistoryView()
                }
            }
            .navigationTitle("Конвертер валют")
            .refreshable {
                await refreshCurrencies()
            }
            .overlay {
                if viewModel.isLoadingCurrencies {
                    loadingOverlay(title: "Загрузка валют…")
                } else if viewModel.isConverting {
                    loadingOverlay(title: "Конвертация…")
                }
            }
            .onChange(of: viewModel.errorMessage) { _, newValue in
                // Показываем alert только для non-recoverable ошибок
                if let error = newValue, !error.isEmpty {
                    showErrorAlert = isNonRecoverableError(error)
                }
            }
            .alert("Ошибка", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                Task {
                    await refreshCurrencies()
                }
            }
        }
    }

    @ViewBuilder
    private func loadingOverlay(title: String) -> some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.8)
            VStack {
                ProgressView()
                    .scaleEffect(1.5)
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(.top, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func refreshCurrencies() async {
        viewModel.loadCurrencies()
        try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s для визуального эффекта refresh
    }

    private func isNonRecoverableError(_ error: String) -> Bool {
        // Non-recoverable ошибки: валидация, конфигурация
        let nonRecoverableKeywords = [
            "Неверный формат",
            "Некорректная",
            "Не указаны",
            "Конфигурация"
        ]
        return nonRecoverableKeywords.contains { error.contains($0) }
    }
}
