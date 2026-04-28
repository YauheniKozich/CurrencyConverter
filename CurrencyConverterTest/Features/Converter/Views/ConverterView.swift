//
//  ConverterView.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import SwiftUI

struct ConverterView: View {
    private enum UI {
        static let textFieldCornerRadius: CGFloat = 8
        static let textFieldBorderWidth: CGFloat = 2
        static let debounceNanoseconds: UInt64 = 300_000_000
    }

    @Bindable var viewModel: ConverterViewModel
    @State private var amountInput: String = ""
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                currencySelectionSection
                currencySelectionFeedbackSection
                currenciesErrorSection
                amountSection
                convertButtonSection
                resultSection
                errorSection
                navigationLinks
            }
            .navigationTitle("Конвертер валют")
            .refreshable {
                await viewModel.refreshCurrencies()
            }
            .overlay { loadingOverlay }
            .alert("Ошибка", isPresented: Binding(
                get: { viewModel.showErrorAlert },
                set: { isPresented in
                    if !isPresented {
                        viewModel.clearError()
                    }
                }
            )) {
                Button("OK", role: .cancel) {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                await viewModel.loadCurrenciesAsync()
            }
        }
    }

    // MARK: - Form Sections

    @ViewBuilder
    private var currencySelectionSection: some View {
        Section(header: Text("Выбор валют")) {
            Picker("Из", selection: $viewModel.fromCurrency) {
                ForEach(viewModel.currencies, id: \.self) { currency in
                    Text(currency).tag(currency)
                }
            }
            .accessibilityLabel("Валюта конвертации")
            .disabled(viewModel.currencies.isEmpty)

            Picker("В", selection: $viewModel.toCurrency) {
                ForEach(viewModel.currencies, id: \.self) { currency in
                    Text(currency).tag(currency)
                }
            }
            .accessibilityLabel("Целевая валюта")
            .disabled(viewModel.currencies.isEmpty)
        }
    }

    @ViewBuilder
    private var currencySelectionFeedbackSection: some View {
        if viewModel.currencies.isEmpty && !viewModel.isLoadingCurrencies {
            if let error = viewModel.currenciesLoadingError {
                feedbackSection(
                    title: "Не удалось загрузить валюты",
                    systemImage: "exclamationmark.triangle.fill",
                    description: error,
                    actionTitle: "Попробовать снова"
                ) {
                    Task {
                        await viewModel.loadCurrenciesAsync()
                    }
                }
            } else {
                feedbackSection(
                    title: "Нет доступных валют",
                    systemImage: "globe",
                    description: "Попробуйте обновить список",
                    actionTitle: "Обновить"
                ) {
                    Task {
                        await viewModel.loadCurrenciesAsync()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var currenciesErrorSection: some View {
        if let error = viewModel.currenciesLoadingError, !viewModel.currencies.isEmpty {
            feedbackSection(
                title: "Не удалось обновить список валют",
                systemImage: "exclamationmark.triangle.fill",
                description: error,
                actionTitle: "Попробовать снова"
            ) {
                Task {
                    await viewModel.loadCurrenciesAsync()
                }
            }
        }
    }

    @ViewBuilder
    private var amountSection: some View {
        Section(header: Text("Сумма")) {
            TextField("Введите сумму", text: $amountInput)
                .keyboardType(.decimalPad)
                .submitLabel(.done)
                .accessibilityLabel("Сумма для конвертации")
                .accessibilityHint("Введите числовое значение")
                .overlay(
                    RoundedRectangle(cornerRadius: UI.textFieldCornerRadius)
                        .stroke(viewModel.hasValidationError ? Color.red : Color.clear, lineWidth: UI.textFieldBorderWidth)
                )
                .onChange(of: amountInput) { _, newValue in
                    guard newValue != viewModel.amount else { return }
                    debounceTask?.cancel()
                    debounceTask = Task { [weak viewModel] in
                        do {
                            try await Task.sleep(nanoseconds: UI.debounceNanoseconds)
                            viewModel?.setAmount(newValue)
                        } catch {
                            return
                        }
                    }
                }
                .onAppear {
                    amountInput = viewModel.amount
                }
                .onChange(of: viewModel.amount) { _, newValue in
                    guard amountInput != newValue else { return }
                    amountInput = newValue
                }
        }
    }

    @ViewBuilder
    private var convertButtonSection: some View {
        Section {
            Button("Конвертировать") {
                viewModel.convert()
            }
            .accessibilityLabel("Конвертировать валюту")
            .accessibilityHint("Нажмите для выполнения конвертации")
            .disabled(!viewModel.isValidAmount || viewModel.currencies.isEmpty)
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if !viewModel.result.isEmpty {
            Section(header: Text("Результат")) {
                Text(viewModel.formattedResult)
                    .accessibilityLabel("Результат: \(viewModel.formattedResult)")
                Text("Курс: \(viewModel.rate)")
                    .accessibilityLabel("Курс обмена: \(viewModel.rate)")
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.errorMessage, !viewModel.hasValidationError {
            feedbackSection(
                title: "Не удалось выполнить конвертацию",
                systemImage: "exclamationmark.circle.fill",
                description: error,
                actionTitle: "Попробовать снова",
                isProminentAction: false
            ) {
                viewModel.convert()
            }
        }
    }

    @ViewBuilder
    private var navigationLinks: some View {
        Section {
            NavigationLink("История") {
                HistoryView()
            }
            .accessibilityLabel("Перейти к истории конвертаций")
        }
    }

    // MARK: - Overlays

    @ViewBuilder
    private var loadingOverlay: some View {
        if viewModel.isLoadingCurrencies {
            ScreenLoadingOverlayView(title: "Загрузка валют…")
        } else if viewModel.isConverting {
            ScreenLoadingOverlayView(title: "Конвертация…")
        }
    }

    @ViewBuilder
    private func feedbackSection(
        title: String,
        systemImage: String,
        description: String? = nil,
        actionTitle: String? = nil,
        isProminentAction: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Section {
            ScreenFeedbackView(
                title: title,
                systemImage: systemImage,
                description: description,
                actionTitle: actionTitle,
                isProminentAction: isProminentAction,
                action: action
            )
        }
    }
}
