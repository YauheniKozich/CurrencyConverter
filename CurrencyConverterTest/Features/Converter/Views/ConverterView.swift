//
//  ConverterView.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import SwiftUI
import SwiftData

struct ConverterView: View {
    private enum UI {
        static let textFieldCornerRadius: CGFloat = 8
        static let textFieldBorderWidth: CGFloat = 2
        static let debounceNanoseconds: UInt64 = 300_000_000
        static let quickPresets = [10, 50, 100, 500, 1000]
    }

    @Bindable var viewModel: ConverterViewModel
    let historyViewModel: HistoryViewModel
    @State private var amountInput: String = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var swapRotation: Double = 0
    @FocusState private var isAmountFocused: Bool

    private enum CurrencySelectionTarget: Identifiable {
        case from
        case to

        var id: String {
            switch self {
            case .from: return "from"
            case .to: return "to"
            }
        }
    }

    @State private var activeCurrencySelection: CurrencySelectionTarget?
    @State private var networkMonitor = NetworkMonitor.shared
    @State private var showSettingsSheet = false

    var body: some View {
        NavigationStack {
            Form {
                offlineBannerSection
                currencySelectionSection
                currencySelectionFeedbackSection
                currenciesErrorSection
                amountSection
                convertButtonSection
                resultSection
                errorSection
                navigationLinks
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.result.isEmpty)
            .navigationTitle("Конвертер валют")
            .refreshable {
                await viewModel.refreshCurrencies()
            }
            .overlay { loadingOverlay }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Настройки")
                    .accessibilityHint("Открывает экран настроек и статуса кэша")
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        isAmountFocused = false
                    }
                    .accessibilityLabel("Скрыть клавиатуру")
                }
            }
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
                networkMonitor.onRestoration {
                    Task {
                        await viewModel.loadCurrenciesAsync()
                        if viewModel.isValidAmount {
                            viewModel.convert()
                        }
                    }
                }
                await viewModel.loadCurrenciesAsync()
            }
            .sheet(item: $activeCurrencySelection) { target in
                CurrencyPickerSheet(
                    title: target == .from ? "Из валюты" : "В валюту",
                    selectedCurrency: Binding(
                        get: { target == .from ? viewModel.fromCurrency : viewModel.toCurrency },
                        set: { newCode in
                            if target == .from {
                                viewModel.fromCurrency = newCode
                            } else {
                                viewModel.toCurrency = newCode
                            }
                            if viewModel.isValidAmount {
                                viewModel.convert()
                            }
                        }
                    ),
                    availableCurrencies: viewModel.currencies
                )
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsSheet(
                    currenciesCount: viewModel.currencies.count,
                    onRefreshCurrencies: {
                        await viewModel.refreshCurrencies()
                    }
                )
            }
            .sensoryFeedback(.success, trigger: viewModel.result) { oldValue, newValue in
                !newValue.isEmpty && oldValue != newValue
            }
            .sensoryFeedback(.error, trigger: viewModel.errorMessage) { oldValue, newValue in
                newValue != nil && oldValue != newValue
            }
            .sensoryFeedback(.selection, trigger: viewModel.fromCurrency)
            .sensoryFeedback(.selection, trigger: viewModel.toCurrency)
        }
    }

    // MARK: - Form Sections

    @ViewBuilder
    private var offlineBannerSection: some View {
        if !networkMonitor.isConnected {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.orange)
                        .font(.headline)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Нет подключения к сети")
                            .font(.subheadline.weight(.semibold))
                        Text("Используются сохранённые курсы валют")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Нет подключения к сети. Используются сохранённые курсы валют.")
        }
    }

    @ViewBuilder
    private var currencySelectionSection: some View {
        Section(header: Text("Выбор валют")) {
            currencySelectorRow(
                title: "Из",
                currencyCode: viewModel.fromCurrency,
                target: .from
            )

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    swapRotation += 180
                }
                viewModel.swapCurrencies()
            } label: {
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                        .rotationEffect(.degrees(swapRotation))
                        .font(.body)
                    Text("Поменять местами")
                        .font(.subheadline)
                }
            }
            .disabled(viewModel.currencies.isEmpty)
            .accessibilityLabel("Поменять местами")
            .accessibilityHint("Меняет выбранные валюты местами")

            currencySelectorRow(
                title: "В",
                currencyCode: viewModel.toCurrency,
                target: .to
            )
        }
    }

    @ViewBuilder
    private func currencySelectorRow(
        title: String,
        currencyCode: String,
        target: CurrencySelectionTarget
    ) -> some View {
        let item = CurrencyItem(code: currencyCode)
        Button {
            activeCurrencySelection = target
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 24, alignment: .leading)

                Text(item.flag)
                    .font(.title3)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.code)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)

                    Text(item.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.currencies.isEmpty)
        .accessibilityLabel("\(title): \(item.code), \(item.name)")
        .accessibilityHint("Нажмите для выбора другой валюты")
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
                .focused($isAmountFocused)
                .accessibilityLabel("Сумма для конвертации")
                .accessibilityHint("Введите числовое значение")
                .overlay(
                    RoundedRectangle(cornerRadius: UI.textFieldCornerRadius)
                        .stroke(viewModel.hasValidationError ? Color.red : Color.clear, lineWidth: UI.textFieldBorderWidth)
                )
                .onChange(of: amountInput) { _, newValue in
                    guard newValue != viewModel.amount else { return }
                    debounceTask?.cancel()
                    let model = viewModel
                    debounceTask = Task { [weak model] in
                        do {
                            try await Task.sleep(nanoseconds: UI.debounceNanoseconds)
                            model?.setAmount(newValue)
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(UI.quickPresets, id: \.self) { preset in
                        Button {
                            let strValue = "\(preset)"
                            amountInput = strValue
                            viewModel.setAmount(strValue)
                        } label: {
                            Text("\(preset)")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemFill))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Выбрать сумму \(preset)")
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private var convertButtonSection: some View {
        Section {
            Button("Конвертировать") {
                isAmountFocused = false
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
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.formattedResult)
                        .font(.title2.weight(.bold))
                        .contentTransition(.numericText())
                        .animation(.snappy, value: viewModel.result)
                        .accessibilityLabel("Результат: \(viewModel.formattedResult)")

                    Divider()
                        .padding(.vertical, 2)

                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Прямой курс")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(viewModel.directRateText)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                        }

                        Spacer()

                        if !viewModel.inverseRateText.isEmpty {
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("Обратный курс")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(viewModel.inverseRateText)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Прямой курс: \(viewModel.directRateText). Обратный курс: \(viewModel.inverseRateText)")
                }

                if viewModel.isOfflineRate {
                    Label("Использован сохранённый курс (офлайн)", systemImage: "wifi.slash")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .accessibilityLabel("Курс загружен из локального хранилища, так как интернет недоступен")
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
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
            NavigationLink {
                HistoryView(viewModel: historyViewModel) { entry in
                    viewModel.applyHistoryEntry(entry)
                    amountInput = viewModel.amount
                }
            } label: {
                Text("История")
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
#Preview("Default") {
    ConverterPreviewContainerView()
}

#Preview("Accessibility Text Size") {
    ConverterPreviewContainerView()
        .environment(\.dynamicTypeSize, .accessibility2)
}

private struct ConverterPreviewContainerView: View {
    var body: some View {
        if let view = makePreview() {
            view
        } else {
            Text("Preview unavailable")
        }
    }

    private func makePreview() -> AnyView? {
        do {
            let schema = Schema([Conversion.self, ExchangeRate.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: config)
            let appConfig = try AppConfiguration(
                apiKey: "preview_key",
                apiBaseURL: URL(string: "https://api.currencyapi.com/v3/")!,
                cacheTTL: 3600
            )
            let dependencies = AppDependencies(config: appConfig, database: container)
            let repo = try dependencies.createRepository()
            let actor = try ConversionHistoryActor(modelContainer: container)

            let viewModel = ConverterViewModel(
                conversionUseCase: CurrencyConversionUseCase(repository: repo),
                loadCurrenciesUseCase: LoadCurrenciesUseCase(repository: repo),
                saveConversionHistoryUseCase: SaveConversionHistoryUseCase(historyActor: actor),
                numberFormatter: NumberFormatterService(locale: .current),
                preferences: UserPreferences(defaults: .standard)
            )

            let historyViewModel = HistoryViewModel(
                historyUseCase: ConversionHistoryUseCase(historyActor: actor)
            )

            return AnyView(
                NavigationStack {
                    ConverterView(viewModel: viewModel, historyViewModel: historyViewModel)
                }
                .modelContainer(container)
            )
        } catch {
            return nil
        }
    }
}

