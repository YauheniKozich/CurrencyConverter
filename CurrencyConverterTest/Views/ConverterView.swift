//
//  ConverterView.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import SwiftUI
import SwiftData

struct ConverterView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel: ConverterViewModel

    init(context: ModelContext) {
        _viewModel = StateObject(wrappedValue: ConverterViewModel(repository: CurrencyAPIRepository(context: context)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Выбор валют")) {
                    Picker("Из", selection: $viewModel.fromCurrency) {
                        ForEach(viewModel.currencies, id: \.self) { Text($0) }
                    }
                    .disabled(viewModel.currencies.isEmpty)
                    Picker("В", selection: $viewModel.toCurrency) {
                        ForEach(viewModel.currencies, id: \.self) { Text($0) }
                    }
                    .disabled(viewModel.currencies.isEmpty)
                }

                Section(header: Text("Сумма")) {
                    TextField("Введите сумму", text: $viewModel.amount)
                        .keyboardType(.decimalPad)
                        .onChange(of: viewModel.amount) { _, newValue in
                            var filtered = newValue
                                .replacingOccurrences(of: ",", with: ".")
                                .filter { "0123456789.".contains($0) }
                            let components = filtered.split(separator: ".")
                            if components.count > 2 {
                                filtered = components.prefix(2).joined(separator: ".")
                            }
                            viewModel.amount = filtered
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(viewModel.errorMessage == "Неверный формат суммы" ? Color.red : Color.clear, lineWidth: 1)
                        )
                }

                if viewModel.isLoadingCurrencies {
                    ProgressView("Загрузка валют…")
                }

                if let error = viewModel.currenciesLoadingError {
                    Text(error)
                        .foregroundColor(.red)
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
                    Text(error)
                        .foregroundStyle(.red)
                }

                NavigationLink("История") {
                    HistoryView()
                }
            }
            .navigationTitle("Конвертер валют")
            .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                viewModel.loadCurrencies()
            }
        }
    }
}
