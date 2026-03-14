# Currency Converter Test

Конвертер валют с кэшированием курсов и историей конвертаций.

## Возможности

- ✅ Конвертация между 150+ валютами
- ✅ Кэширование курсов (1 час)
- ✅ История конвертаций (SwiftData)
- ✅ Pull-to-refresh для обновления курсов
- ✅ Работа офлайн (по кэшу)
- ✅ Умное кэширование (сравнение по hash)

## Архитектура

Приложение следует **Clean Architecture + MVVM**:

```
┌─────────────────────────────────────────────────────────────┐
│                      Presentation Layer                      │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │  ConverterView  │  │   HistoryView   │                  │
│  └────────┬────────┘  └─────────────────┘                  │
│           │                                                 │
│  ┌────────▼────────┐                                        │
│  │ ConverterVM     │  (ViewModel)                           │
│  └────────┬────────┘                                        │
└───────────┼─────────────────────────────────────────────────┘
            │
┌───────────▼─────────────────────────────────────────────────┐
│                        Domain Layer                          │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ CurrencyConv.   │  │ LoadCurrencies  │  (UseCases)      │
│  │ UseCase         │  │ UseCase         │                  │
│  └────────┬────────┘  └─────────────────┘                  │
└───────────┼─────────────────────────────────────────────────┘
            │
┌───────────▼─────────────────────────────────────────────────┐
│                         Data Layer                           │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ CurrencyAPI     │  │  CurrencyLocal  │  (Repositories)  │
│  │ Repository      │  │  DataSource     │                  │
│  └────────┬────────┘  └────────┬────────┘                  │
│           │                    │                            │
│  ┌────────▼────────┐  ┌───────▼────────┐                  │
│  │ NetworkService  │  │ SwiftData      │  (Sources)       │
│  │                 │  │ - ExchangeRate │                  │
│  │                 │  │ - Conversion   │                  │
│  └─────────────────┘  └────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
```

## Структура проекта

```
CurrencyConverterTest/
├── App/                          # Точка входа
│   ├── CurrencyConverterTestApp.swift
│   └── ErrorView.swift
├── Assembly/                     # Dependency Injection
│   ├── AppConfiguration.swift
│   └── DependencyContainer.swift
├── Core/                         # Общефункциональные компоненты
│   ├── Constants/
│   ├── Errors/                   # AppError (LocalizedError)
│   ├── Logging/                  # Logger (os.log)
│   ├── Services/
│   │   ├── Formatters/           # NumberFormatterService
│   │   └── Keychain/             # KeychainHelper
│   └── Utilities/                # APIKeyLoader
├── Data/                         # Data Layer
│   ├── Actors/                   # ConversionHistoryActor
│   ├── Cache/                    # CurrencyCacheManager
│   ├── DataSources/
│   │   └── Local/                # CurrencyLocalDataSource
│   ├── Network/
│   │   ├── CurrencyAPIEndpoint.swift
│   │   ├── NetworkError+AppError.swift
│   │   └── NetworkService.swift
│   └── Repositories/
│       ├── CurrencyAPIRepository.swift
│       └── CurrencyRepository.swift
├── Features/                     # Функциональные модули
│   ├── Converter/
│   │   ├── UseCases/
│   │   ├── ViewModels/
│   │   └── Views/
│   └── History/
│       ├── UseCases/
│       └── Views/
└── Models/
    ├── Data/                     # SwiftData модели
    │   ├── Conversion.swift
    │   ├── CurrencyDTO.swift
    │   └── ExchangeRate.swift
    └── Domain/                   # Domain модели
        └── ConversionResult.swift
```

## Поток данных

### Конвертация валют:

```
1. Пользователь вводит сумму
   ↓
2. ViewModel.validateAmount()
   ↓
3. UseCase.execute(from, to, amount)
   ↓
4. Repository.convert()
   ↓
5. [Кэш] Проверяем CurrencyCacheManager
   ├─ Есть актуальный → Возвращаем
   └─ Нет → Запрос к API
       ↓
6. [API] NetworkService.request()
   ↓
7. [Кэш] Сохраняем курс в SwiftData
   ↓
8. [История] Сохраняем конвертацию
   ↓
9. ViewModel обновляет UI
```

### Обновление курсов (Pull-to-Refresh):

```
1. Пользователь делает свайп вниз
   ↓
2. View.refreshCurrencies()
   ↓
3. ViewModel.refreshCurrencies()
   ↓
4. UseCase.execute(forceRefresh: true)
   ↓
5. Repository.refreshSupportedCurrencies()
   ↓
6. [Кэш] Инвалидируем CurrencyCacheManager
   ↓
7. [API] Загружаем новый список валют
   ↓
8. [Кэш] Сохраняем hash для сравнения
   ↓
9. ViewModel обновляет UI
```

## Кэширование

### Двухуровневая система:

| Уровень | Хранилище | Данные | TTL |
|---------|-----------|--------|-----|
| **L1** | In-memory (RAM) | Список валют | До перезапуска |
| **L2** | SwiftData (Disk) | Курсы валют | 1 час |

### Умное кэширование:

```swift
// Сравниваем hash кодов валют
let currentHash = calculateCurrenciesHash(currencies)

if currentHash == lastCurrenciesHash {
    return cachedCurrencies  // Данные не изменились
} else {
    cachedCurrencies = currencies  // Обновляем кэш
}
```

**Выгода:**
- ✅ Не парсим JSON если данные не изменились
- ✅ Экономия CPU и трафика
- ✅ Автоматическое обновление при изменении API

### Fallback при ошибках:

```swift
if appError.isRecoverable,
   let staleRate = try? cacheManager.getStaleCachedRate(...) {
    return ConversionResult(result: amount * staleRate, rate: staleRate)
}
```

**Работает офлайн:** Используем последний известный курс.

## Технологии

| Компонент | Технология |
|-----------|------------|
| **UI** | SwiftUI |
| **Архитектура** | MVVM + Clean Architecture |
| **DI** | Manual (DependencyContainer) |
| **DB** | SwiftData |
| **Network** | URLSession |
| **Concurrency** | async/await, Task, Actor |
| **Кэширование** | In-memory + SwiftData |
| **Логирование** | os.Logger |

## Зависимости

- **System Frameworks:**
  - SwiftUI
  - SwiftData
  - Foundation
  - Network (NWPathMonitor)

- **External:**
  - Отсутствуют

## Запуск

1. Откройте `CurrencyConverterTest.xcodeproj`
2. Добавьте API ключ в `Config.plist`:
   ```xml
   <key>CurrencyAPIKey</key>
   <string>YOUR_API_KEY</string>
   ```
3. Или задайте в схеме: `CURRENCY_API_KEY=YOUR_API_KEY`
4. Запустите проект

## Тесты

```bash
xcodebuild test \
  -project CurrencyConverterTest.xcodeproj \
  -scheme CurrencyConverterTest \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

**Покрытие:**
- ConverterViewModel: 8 тестов
- CurrencyCacheManager: 10 тестов
- NumberFormatterService: 10 тестов
- AppConfiguration: 4 теста
- CurrencyAPIRepository: 3 теста

## Метрики

| Метрика | Значение |
|---------|----------|
| **Файлов** | 28 |
| **Строк кода** | ~1700 |
| **Тестов** | 38 |
| **Покрытие** | ~60% |

## Best Practices

- ✅ **SOLID** принципы
- ✅ **Clean Architecture** (Domain/Data/Presentation)
- ✅ **MVVM** для UI
- ✅ **Actor** для thread safety
- ✅ **Sendable** для concurrency
- ✅ **LocalizedError** для ошибок
- ✅ **os.Logger** для логов
- ✅ **SwiftData** для персистентности
