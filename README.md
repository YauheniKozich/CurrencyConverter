# Currency Converter Test

Конвертер валют с кэшированием курсов и историей конвертаций.

## Возможности

- ✅ Конвертация между 150+ валютами
- ✅ Кэширование курсов (1 час)
- ✅ История конвертаций (SwiftData)
- ✅ Pull-to-refresh для обновления курсов
- ✅ Работа офлайн (по кэшу)
- ✅ Умное кэширование (сравнение по hash)
- ✅ Accessibility (VoiceOver, Dynamic Type)
- ✅ Empty states и retry mechanisms
- ✅ Debounce для ввода суммы

## Что уже сделал

- Привел проект к более стандартной iOS-структуре: `App`, `Domain`, `Data`, `Features`, `Core`, `Resources` и тестовые таргеты
- Вынес composition root в `App/CompositionRoot`
- Разделил storage-слой на `Cache`, `Persistence` и локальные `DataSources`
- Вынес доменную модель `ConversionResult` в `Domain/Models`
- Упростил первый запуск конвертера: загрузка валют идёт cache-first, без лишнего принудительного refresh
- Убрал polling из обновления валют и лишние task-обёртки на retry
- Перевел поиск истории на SwiftData predicate и отдельный `HistoryListView`
- Разрезал `ConversionService` на orchestration и вынес presentation formatting в `ConversionPresentationFormatter`
- Вынес общие состояния экрана в `Features/Shared/Presentation`
- Сделал alert bindings нормальными, без `.constant(...)`
- Вынес общие тестовые JSON-фикстуры и response helper в `TestHelpers`
- Починил сборку UI test runner, чтобы `build-for-testing` проходил в CLI

## Архитектура

Приложение построено по **Clean Architecture + MVVM** с использованием **Swift 6 Concurrency**.

- `App` содержит точку входа и composition root
- `Domain` хранит чистые модели, не зависящие от UI, сети или БД
- `Data` отвечает за сеть, кэш, persistence и репозитории
- `Features` содержит экраны, view models, use cases и feature-specific services
- `Core` хранит общие сервисы, ошибки, preferences и utilities

## Структура проекта

```
CurrencyConverterTest/
├── App/
│   ├── CurrencyConverterTestApp.swift
│   └── CompositionRoot/
│       ├── AppConfiguration.swift
│       └── DependencyContainer.swift
├── Core/
│   ├── Constants/
│   ├── Errors/
│   │   ├── AppError.swift
│   │   └── ErrorTypeMapper.swift
│   ├── Logging/
│   ├── Preferences/
│   ├── Services/
│   │   ├── Formatters/
│   │   └── Keychain/
│   └── Utilities/
├── Domain/
│   └── Models/
│       └── ConversionResult.swift
├── Data/
│   ├── Storage/
│   │   ├── Cache/
│   │   ├── DataSources/
│   │   │   └── Local/
│   │   └── Persistence/
│   │       ├── Actors/
│   │       └── Entities/
│   │           ├── Conversion.swift
│   │           └── ExchangeRate.swift
│   ├── Network/
│   │   ├── DTOs/
│   │   │   └── CurrencyDTO.swift
│   │   ├── CurrencyAPIEndpoint.swift
│   │   ├── NetworkError+AppError.swift
│   │   └── NetworkService.swift
│   └── Repositories/
│       ├── CurrencyAPIRepository.swift
│       └── CurrencyRepository.swift
├── Features/
│   ├── Converter/
│   │   ├── Services/
│   │   │   ├── ConversionPresentationFormatter.swift
│   │   │   └── ConversionService.swift
│   │   ├── UseCases/
│   │   │   ├── CurrencyConversionUseCase.swift
│   │   │   ├── LoadCurrenciesUseCase.swift
│   │   │   └── *.protocol.swift
│   │   ├── ViewModels/
│   │   │   └── ConverterViewModel.swift
│   │   └── Views/
│   │       └── ConverterView.swift
│   └── History/
│       ├── UseCases/
│       │   ├── SaveConversionHistoryUseCase.swift
│       │   └── ConversionHistoryUseCaseProtocol.swift
│       ├── ViewModels/
│       │   └── HistoryViewModel.swift
│       └── Views/
│           ├── HistoryListView.swift
│           └── HistoryView.swift
│   └── Shared/
│       └── Presentation/
│           ├── ScreenFeedbackView.swift
│           └── ScreenLoadingOverlayView.swift
├── Resources/
│   ├── Assets.xcassets/
│   └── Config.plist
├── CurrencyConverterTestTests/
└── CurrencyConverterTestUITests/
```

### Правила размещения файлов

- `App/` - запуск приложения, DI, composition root
- `Domain/` - чистые модели и бизнес-сущности без зависимости от UI и инфраструктуры
- `Data/Network/DTOs` - модели сетевых ответов
- `Data/Storage/Persistence/Entities` - SwiftData/Core Data сущности
- `Data/Storage/Persistence/Actors` - акторы, которые работают с persistence
- `Data/Storage/Cache` - in-memory и TTL-кэш
- `Data/Storage/DataSources/Local` - локальные источники данных
- `Data/Repositories` - реализация доступа к данным
- `Features/*` - экраны, view models, use cases и feature-specific services
- `Features/Shared/Presentation` - общие экранные состояния: loading, empty, error, retry
- `Core/` - переиспользуемые общие сервисы, ошибки и утилиты

## Чего добился

- Структура проекта стала предсказуемой и ближе к общепринятой iOS-схеме
- Домен больше не смешан с storage-реализациями
- Кэш и persistence разнесены по понятным папкам
- UI стал меньше знать об инфраструктуре
- Первый экран стал отзывчивее за счёт cache-first загрузки
- Поиск по истории перенесён в SwiftData predicate, поэтому список не фильтруется вручную в `body`
- Loading, empty, error и retry состояния оформлены единообразно через shared presentation views
- Сборка `build` и `build-for-testing` проходят успешно

## Поток данных

### Конвертация валют:

```
1. Пользователь вводит сумму (с debounce 300ms)
   ↓
2. ViewModel.setAmount()
   ↓
3. Пользователь нажимает "Конвертировать"
   ↓
4. ViewModel.convert()
   ↓
5. ConversionService.convert()
   ↓
6. [Кэш] CurrencyCacheManager.getCachedRate()
   ├─ Есть актуальный → Возвращаем
   └─ Нет → UseCase.execute()
       ↓
7. Repository.convert()
   ↓
8. [API] NetworkService.request()
   ↓
9. [Кэш] Сохраняем курс (actor-safe)
   ↓
10. [История] ConversionHistoryActor.save()
    ↓
11. ViewModel обновляет UI
```

### Обновление курсов (Pull-to-Refresh):

```
1. Пользователь делает свайп вниз
   ↓
2. View.refreshCurrencies()
   ↓
3. ViewModel.refreshCurrencies() (ждём завершения)
   ↓
4. UseCase.execute(forceRefresh: true)
   ↓
5. Repository.refreshSupportedCurrencies()
   ↓
6. [Actor] CurrencyCacheManager.invalidateCurrenciesCache()
   ↓
7. [API] Загружаем новый список валют
   ↓
8. [Actor] Сравниваем hash → Обновляем кэш
   ↓
9. ViewModel обновляет UI
```

### Обработка ошибок:

```
1. ErrorTypeMapper.classify(error)
   ├─ .validation → Показываем inline (красная рамка)
   ├─ .configuration → Alert (non-recoverable)
   ├─ .network → Fallback на stale cache
   └─ .unknown → Alert с retry
```

## Кэширование

### Трёхуровневая система:

| Уровень | Хранилище | Данные | TTL | Thread Safety |
|---------|-----------|--------|-----|---------------|
| **L1** | In-memory (RAM) | Список валют | До перезапуска | Actor (CurrencyCacheManager) |
| **L2** | SwiftData (Disk) | Курсы валют | 1 час | Actor (ConversionHistoryActor) |
| **L3** | UserDefaults | Preferences | Бессрочно | @MainActor (UserPreferences) |

### Умное кэширование:

```swift
// CurrencyCacheManager (actor)
func getCurrencies(load: @escaping @Sendable () async throws -> [String: Currency]) async throws {
    // Actor автоматически синхронизирует доступ
    if let cached = cachedCurrencies, !forceRefresh {
        return cached  // In-memory hit
    }
    
    let currencies = try await load()
    let currentHash = calculateCurrenciesHash(currencies)
    
    if currentHash == lastCurrenciesHash {
        return cachedCurrencies  // Hash match → не обновляем
    }
    
    cachedCurrencies = currencies  // Обновляем кэш
    lastCurrenciesHash = currentHash
    return currencies
}
```

**Выгода:**
- ✅ Actor обеспечивает thread-safety автоматически
- ✅ Не парсим JSON если данные не изменились
- ✅ Экономия CPU и трафика
- ✅ Автоматическое обновление при изменении API

### Fallback при ошибках:

```swift
if appError.isRecoverable,
   let staleRate = try? await cacheManager.getStaleCachedRate(...) {
    return ConversionResult(result: amount * staleRate, rate: staleRate)
}
```

**Работает офлайн:** Используем последний известный курс даже с истёкшим TTL.

## Технологии

| Компонент | Технология |
|-----------|------------|
| **UI** | SwiftUI |
| **Архитектура** | MVVM + Clean Architecture |
| **DI** | Manual (DependencyContainer) |
| **DB** | SwiftData |
| **Network** | URLSession |
| **Concurrency** | async/await, Task, Actor |
| **Global Actors** | @MainActor, custom actors |
| **Кэширование** | In-memory (actor) + SwiftData |
| **Логирование** | os.Logger |
| **Accessibility** | VoiceOver, Dynamic Type |
| **Swift Version** | 6.0+ |

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
| **Файлов** | 52 |
| **Строк кода** | ~2100 |
| **Тестов** | 38 |
| **Покрытие** | ~65% |
| **Swift Version** | 6.0 |
| **iOS Deployment** | 18.4+ |

## Best Practices

- ✅ **SOLID** принципы
- ✅ **Clean Architecture** (App/Domain/Data/Features/Core)
- ✅ **MVVM** для UI
- ✅ **Actor** для thread-safe состояния
- ✅ **Sendable** для concurrency safety
- ✅ **@MainActor** для UI и ViewModel
- ✅ **LocalizedError** для ошибок
- ✅ **os.Logger** для логов
- ✅ **SwiftData** для персистентности
- ✅ **Accessibility** (VoiceOver, Dynamic Type)
- ✅ **Composited Views** для читаемости
- ✅ **Debounce** для input полей
- ✅ **Empty States** и retry mechanisms
