# Currency Converter Test

Современный iOS-конвертер валют на **SwiftUI** и **SwiftData** с чистой архитектурой (**Clean Architecture + MVVM**), многоуровневым кэшированием, офлайн-режимом, системными командами **App Intents (Siri & Shortcuts)**, поддержкой **Dynamic Type / VoiceOver** и 100% двуязычной локализацией через **String Catalogs**.

---

## 🚀 Возможности приложения

- 🪙 **Конвертация валют**: мгновенный расчет между 150+ мировыми валютами с форматированием с учетом локали пользователя (`NumberFormatterService`).
- 🔍 **Поиск и выбор валют (Searchable Sheet)**:
  - Вместо стандартного меню выбора — нативный модальный экран (`CurrencyPickerSheet`) с быстрым полнотекстовым поиском (`.searchable`) по коду валюты (USD, EUR, GBP) или локализованному названию («Доллар», «Евро»).
  - **Пользовательские избранные валюты (Favorites)**: любая валюта может быть добавлена в избранное тапом по звёздочке или свайпом слева направо. Избранные валюты закрепляются отдельной секцией вверху списка, поддерживают тактильный отклик (`sensoryFeedback`) и надёжно сохраняются в `UserDefaults` через `UserPreferences`.
- **Виджет для рабочего стола (WidgetKit)**: отдельный таргет `CurrencyConverterWidgetExtension`, поддерживающий размеры `.systemSmall` (курс основной пары с флагами стран) и `.systemMedium` (сетка из 4 популярных валютных курсов с автоматическим обновлением и офлайн-индикатором).
  - Автоматическое сопоставление флагов государств (`CurrencyFlagHelper`) с поддержкой региональных валют (🇪🇺 EUR, 🇬🇧 GBP, 🇺🇸 USD, ₿ BTC, 🪙 XAU и др.).
  - Закреплённая секция популярных валют (USD, EUR, GBP, JPY, CHF, CNY, CAD, AUD, RUB) и полный алфавитный список.
  - Семантическая разметка для VoiceOver и отметка выбранного пункта галочкой.
- 🔄 **Кнопка смены валют (Swap)**: быстрое переключение направления обмена одной кнопкой с плавной пружинной анимацией вращения и автоматическим пересчетом.
- ⚡️ **Чипсы быстрого ввода**: горизонтальный скролл с популярными суммами (10, 50, 100, 500, 1000) для быстрого выбора без клавиатуры.
- ⌨️ **Удобный ввод**: поддержка `@FocusState` и тулбар клавиатуры с кнопкой «Готово» для скрытия `.decimalPad`.
- ⚙️ **Экран настроек (SettingsSheet)**:
  - Просмотр и редактирование API-ключа (сохранённого в Keychain).
  - Мониторинг статуса сети (Онлайн / Офлайн).
  - Статистика кэша: количество сохранённых валют и кнопка ручного принудительного обновления курсов с сервера.
  - Информация о приложении и ссылка на поставщика данных.
- 📡 **Мониторинг сети (NWPathMonitor)**:
  - Сервис `NetworkMonitor` в реальном времени отслеживает состояние интернет-соединения.
  - Анимированный статус-баннер при переходе в офлайн.
  - Автоматическое фоновое обновление курсов валют и перерасчет при восстановлении связи.
- 📱 **100% Offline-First режим**: 
  - **Дисковый кэш списка валют**: автоматическое сохранение 150+ валют на диск (`cached_currencies.json`) при успешном получении от API. При холодном старте без интернета конвертер загружает валюты с диска и полностью работоспособен.
  - **SwiftData Upsert**: обновление курсов в `ExchangeRate` без дублирования записей и очистка устаревших копий.
  - **Fallback на сохранённый курс**: при сбоях сети приложение использует кэш и отображает бейдж с иконкой `wifi.slash`.
- 🔑 **Ввод и настройка API-ключа прямо из UI**:
  - Модальное окно `APIKeyInputSheet` для ввода и изменения ключа в Keychain (`APIKeyStorage`) с активной валидацией через `APIKeyValidator`: перед записью сервис выполняет сетевой запрос к `/v3/status`, проверяя подлинность ключа и отображая индикатор загрузки, понятные ошибки (401 Unauthorized) или предложение сохранить ключ без проверки при отсутствии сети.
- 💾 **История конвертаций (SwiftData)**:
  - Изоляция записи и чтения в фоновом акторе `ConversionHistoryActor`.
  - Автоматическая ротация: хранение до 100 последних записей с автоочисткой старых (`trimHistoryIfNeeded`).
  - Поиск и фильтрация по истории с предикатами SwiftData.
  - Удаление свайпом и полная очистка истории.
  - **Восстановление конвертации по тапу**: нажатие на любую строку в истории мгновенно переносит пару валют и сумму обратно в конвертер и автоматически запускает перерасчёт.
  - **Экспорт в CSV**: кнопка `ShareLink` в тулбаре для экспорта всей истории конвертаций в CSV-файл.
- 🎙️ **App Intents (Siri, «Команды», Spotlight)**:
  - Сущность `CurrencyEntity` с автодополнением и предложениями популярных валют (`CurrencyEntityQuery`).
  - Интент `ConvertCurrencyIntent` для фоновой конвертации валют через Siri и Shortcuts.
  - Автоматическая регистрация команд через `CurrencyAppShortcuts` (`AppShortcutsProvider`).
- 📲 **Тактильный отклик (Haptic Feedback)**: нативная интеграция `.sensoryFeedback` на успешную конвертацию, ошибки валидации и изменение истории.
- 🌐 **Локализация (String Catalogs)**: 100% интерфейса, настроек, диалогов Siri, ошибок и специальных меток переведено через `Localizable.xcstrings` (русский и английский языки).
- ♿️ **Accessibility & Dynamic Type**:
  - Полная поддержка VoiceOver с объединением семантических элементов и скрытием декоративных иконок.
  - Модальная изоляция экрана загрузки (`.isModal`).
  - Поддержка шрифтов от `xSmall` до специальных `accessibility5` с `@ScaledMetric` и адаптивным переносом строк.
  - Соответствие Apple HIG по минимальным зонам нажатия (Touch Targets ≥ 44×44 pt).
- 🎨 **Xcode Canvas (`#Preview`)**: готовые изолированные превью для всех экранов и состояний (обычный размер, большой текст, пустое состояние, со списком).

---

## 🏛 Архитектура

Приложение построено по канонам **Clean Architecture + MVVM** и полностью ориентировано на **Swift 6 Concurrency**:

```
┌────────────────────────────────────────────────────────┐
│                   App & System Layer                   │
│   CurrencyConverterTestApp • AppIntents (Siri/Shortcuts) │
│                DependencyContainer (DI)                │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│                    Features (UI/VM)                    │
│   ConverterView • ConverterViewModel                   │
│   CurrencyPickerSheet • APIKeyInputSheet • SettingsSheet │
│   HistoryView • HistoryListView • HistoryViewModel     │
│   Shared Presentation (Feedback & Loading Overlays)    │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│                      Domain Layer                      │
│   UseCases (CurrencyConversion, LoadCurrencies, etc.)  │
│   Models (ConversionResult, ConversionHistoryEntry)    │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│                       Data Layer                       │
│   Repositories (CurrencyAPIRepository)                 │
│   Cache (CurrencyCacheManager - Actor)                 │
│   Persistence (ConversionHistoryActor - SwiftData)     │
│   Network (NetworkService, CurrencyAPIEndpoint)        │
│   Services (NetworkMonitor, KeychainHelper)            │
└────────────────────────────────────────────────────────┘
```

---

## 📂 Структура проекта

```
CurrencyConverterTest/
├── App/
│   ├── CurrencyConverterTestApp.swift       # Точка входа в приложение
│   └── CompositionRoot/
│       ├── AppConfiguration.swift           # Конфигурация API ключей и таймаутов
│       └── DependencyContainer.swift        # Контейнер зависимостей (DI)
├── Core/
│   ├── Constants/                           # Дефолтные настройки и лимиты
│   ├── Errors/                              # AppError и ErrorTypeMapper
│   ├── Logging/                             # Структурированное логирование Logger
│   ├── Preferences/                         # UserPreferences (@MainActor)
│   ├── Services/
│   │   ├── Formatters/                      # NumberFormatterService
│   │   ├── Keychain/                        # KeychainHelper для безопасного хранения
│   │   └── Network/                         # NetworkMonitor (NWPathMonitor)
│   └── Utilities/                           # CurrencyHelper, APIKeyLoader, APIKeyStorage
├── Domain/
│   ├── Models/                              # Чистые модели (ConversionResult, HistoryEntry)
│   └── Protocols/                           # Протоколы хранилищ и репозиториев
├── Data/
│   ├── Network/                             # NetworkService, DTOs, CurrencyAPIEndpoint
│   ├── Repositories/                        # CurrencyAPIRepository с offline fallback
│   └── Storage/
│       ├── Cache/                           # CurrencyCacheManager (Actor, in-memory + hash + disk fallback)
│       ├── DataSources/Local/               # Локальные источники данных (SwiftData + JSON cache)
│       └── Persistence/
│           ├── Actors/                      # ConversionHistoryActor (SwiftData)
│           └── Entities/                    # SwiftData сущности Conversion и ExchangeRate
├── Features/
│   ├── Converter/                           # Экран конвертера (View, ViewModel, UseCases)
│   │   └── Views/CurrencyPickerSheet.swift  # Searchable модальный выбор валют с флагами
│   ├── History/                             # Экран истории (View, ViewModel, UseCases)
│   ├── Intents/                             # App Intents, Shortcuts и Entities для Siri
│   └── Shared/                              # APIKeyInputSheet, SettingsSheet, Presentation Views
├── Resources/
│   ├── Assets.xcassets                      # Цвета и иконки приложения
│   ├── Config.plist                         # Конфигурационный файл
│   └── Localizable.xcstrings                # Каталог локализации (String Catalog, 100% RU & EN)
├── CurrencyConverterTestTests/              # 77 Unit-тестов
└── CurrencyConverterTestUITests/            # 3 UI-теста запуска и производительности
```

---

## ⚡️ Многоуровневое кэширование и устойчивость

| Уровень | Хранилище | Данные | Срок жизни (TTL) | Thread-Safety |
|:---:|:---:|:---:|:---:|:---:|
| **L1** | In-Memory (RAM) | Список поддерживаемых валют | До перезапуска | Swift Actor (`CurrencyCacheManager`) |
| **L2** | Disk (JSON) | Список поддерживаемых валют | Бессрочно (с автообновлением) | Swift Actor / Local Data Source |
| **L3** | SwiftData (Disk) | Курсы валют + Офлайн-кэш | 1 час (с stale-fallback) | Swift Actor (`CurrencyLocalDataSource`) |
| **L4** | UserDefaults | Выбранные валюты пользователя | Бессрочно | `@MainActor` (`UserPreferences`) |

- **Offline-First Fallback**: При сбое сети или отсутствии интернета репозиторий обращается к методу `cacheManager.getStaleCachedRate()`. Пользователь получает расчет даже при истекшем TTL.
- **Холодный старт офлайн**: Если приложение запущено без интернета, список валют восстанавливается из `cached_currencies.json`.
- **SwiftData Upsert**: Атомарный поиск существующей записи по паре `(from, to)` — курсы не накапливаются в базе бесконечно, а аккуратно обновляются с актуальным `timestamp`.

---

## 🛠 Технологический стек

- **Язык**: Swift 6.0+ (Complete Concurrency Checking, Actors, `@MainActor`)
- **Интерфейс**: SwiftUI (iOS 17+)
- **База данных**: SwiftData
- **Системная интеграция**: App Intents, App Shortcuts, Siri, Spotlight
- **Сеть & Мониторинг**: URLSession (async/await), NWPathMonitor (Network framework)
- **Локализация**: Apple String Catalogs (`.xcstrings`) — 100% покрытие EN и RU
- **Безопасность**: Keychain Services, Clean Bounds Safety
- **Тестирование**: XCTest (80 тестов: 77 Unit + 3 UI)

---

## 🧪 Запуск тестов

Проект имеет 100% прохождение тестового набора:

```bash
xcodebuild test \
  -project CurrencyConverterTest.xcodeproj \
  -scheme CurrencyConverterTest \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Результат:
```
** TEST SUCCEEDED **
80 tests: 80 passed, 0 failed, 0 skipped
```

---

## 🔑 Настройка API ключа

Приложение использует API [CurrencyAPI.com](https://currencyapi.com/):

1. **Через UI приложения**: при первом запуске (если ключ не задан) нажмите кнопку «Ввести API ключ» и вставьте полученный ключ. Он будет безопасно сохранен в Keychain. Изменить его можно в любой момент на экране «Настройки» (шестерёнка в шапке).
2. **Через файл конфигурации**: в файле `Resources/Config.plist` укажите ваш ключ:
   ```xml
   <key>CurrencyAPIKey</key>
   <string>YOUR_API_KEY</string>
   ```
3. **Через переменные окружения**: передайте переменную окружения в схеме сборки: `CURRENCY_API_KEY=YOUR_API_KEY`.
