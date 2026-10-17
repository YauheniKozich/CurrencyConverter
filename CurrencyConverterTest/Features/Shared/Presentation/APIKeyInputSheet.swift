//
//  APIKeyInputSheet.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 17.10.26.
//

import SwiftUI

struct APIKeyInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var errorMessage: String?
    @State private var isValidating: Bool = false
    @State private var showOfflineConfirmation: Bool = false
    @FocusState private var isFieldFocused: Bool

    let validator: any APIKeyValidating
    let onSaved: (String) -> Void

    init(
        validator: any APIKeyValidating = APIKeyValidator(),
        onSaved: @escaping (String) -> Void
    ) {
        self.validator = validator
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Введите ваш API ключ", text: $apiKey)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isFieldFocused)
                        .disabled(isValidating)
                        .submitLabel(.done)
                        .onSubmit {
                            Task { await validateAndSave() }
                        }
                        .accessibilityLabel("Поле ввода API ключа")

                    if let errorMessage {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                                .accessibilityHidden(true)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("API ключ CurrencyAPI")
                } footer: {
                    Text("Для работы приложения требуется ключ сервиса CurrencyAPI.com. Он будет надёжно сохранён в системном Keychain.")
                        .font(.footnote)
                }

                Section {
                    Link(destination: URL(string: "https://currencyapi.com")!) {
                        HStack {
                            Image(systemName: "safari")
                            Text("Получить бесплатный ключ на currencyapi.com")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Настройка API ключа")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .disabled(isValidating)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await validateAndSave() }
                    } label: {
                        if isValidating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Сохранить")
                        }
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
                    .accessibilityLabel(isValidating ? "Проверка ключа..." : "Сохранить")
                }
            }
            .confirmationDialog(
                "Сетевая ошибка",
                isPresented: $showOfflineConfirmation,
                titleVisibility: .visible
            ) {
                Button("Сохранить без проверки") {
                    saveKeyDirectly()
                }
                Button("Отмена", role: .cancel) { }
            } message: {
                Text("Не удалось связаться с сервером для проверки ключа. Сохранить ключ без проверки?")
            }
            .onAppear {
                isFieldFocused = true
            }
        }
    }

    private func validateAndSave() async {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = String(localized: "API ключ не может быть пустым")
            return
        }

        isValidating = true
        errorMessage = nil

        let result = await validator.validate(apiKey: trimmed)
        isValidating = false

        switch result {
        case .valid:
            saveKeyDirectly()
        case .invalid(let message):
            errorMessage = message
        case .networkError:
            showOfflineConfirmation = true
        }
    }

    private func saveKeyDirectly() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let storage = APIKeyStorage()
        storage.save(trimmed)
        onSaved(trimmed)
        dismiss()
    }
}

#Preview {
    APIKeyInputSheet { _ in }
}
