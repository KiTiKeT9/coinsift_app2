<div align="center">

# 💰 CoinSift

**Современное мобильное приложение для управления личными финансами**

Учёт расходов и доходов · Автоимпорт из SMS/push · Аналитика · Финансовые калькуляторы · Инвестиционный портфель

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5%2B-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Material 3](https://img.shields.io/badge/Material-3-757575?logo=materialdesign&logoColor=white)](https://m3.material.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

## ✨ Возможности

### 📊 Учёт финансов
- **Счета и карты** — поддержка дебетовых и кредитных карт, наличных, инвестиционных счетов; кастомные цвета карт с автоматически генерируемыми градиентами
- **Транзакции** — добавление доходов и расходов с богатым списком категорий (Продукты, Транспорт, Здоровье, Развлечения, Шоппинг и др.)
- **Smart-категоризация** — каждая категория имеет иконку и цвет для быстрого визуального восприятия

### � Автоимпорт из SMS и push-уведомлений
- **SMS-листенер** (`SmsListenerService`) — фоновое чтение банковских SMS с разрешением `RECEIVE_SMS` / `READ_SMS`
- **Парсер банковских сообщений** (`SmsParser`) — извлекает сумму, валюту, merchant, тип операции из форматов Сбер, Т-Банк, ВТБ, Альфа, Газпромбанк и др.
- **Push-листенер** (`PushListenerService`) — импорт через `NotificationListenerService` для банков, которые приходят только в виде push
- **Дедупликация** (`TransactionDeduplicator`) — fuzzy-сличение по сумме / времени / merchant, чтобы одна операция из SMS + push не создавала дубль
- **Черновики** (`@/lib/screens/drafts_screen.dart`) — распознанные транзакции попадают в очередь на подтверждение, пользователь решает, сохранять или игнорировать

### �📈 Аналитика
- **Круговая диаграмма расходов и доходов** с переключателем `SegmentedButton`
- **Карточки доходов/расходов** с цветными акцентами
- **Легенда категорий** — топ-4 категории с распределением сумм
- **Общий баланс** по всем активным счетам и динамический период (текущий месяц/год)

### 🧮 Финансовые калькуляторы
- **Ипотека** — расчёт ежемесячного платежа, переплаты, графика
- **Вклады** — доходность с учётом капитализации
- **Кредиты** — аннуитетный и дифференцированный платёж
- **Сравнение банков** — публичные ставки нескольких банков с подсветкой лучшего предложения и подгрузкой логотипов через [Clearbit Logo API](https://clearbit.com/logo)

### 💼 Инвестиции
- **Портфель** — отслеживание акций, облигаций, ETF с автоматическим обновлением цен
- **Каталог инструментов** с живыми ценами и изменением за день через **MOEX ISS API** (batch-endpoint — один HTTP для всех тикеров)
- **Офлайн-кеш каталога** в Hive — список инструментов и последние цены доступны, даже если MOEX недоступен
- **Sparkline 30D** в диалоге добавления актива — график цены закрытия по свечам `iss.moex.com/.../candles.json`
- **Логотипы эмитентов** с **персистентным кешем в Hive** (`LogoCacheService`) — магия-байты защищают от HTML-заглушек, таймауты не помечают URL как битый
- **Безопасное удаление** — swipe-to-delete или явная кнопка-корзина с диалогом подтверждения
- **Прибыль/убыток** — расчёт в абсолютном выражении и в процентах

### 🔐 Безопасность
- **PIN-код** с прогрессивной блокировкой после неверных попыток (30с → 1мин → 5мин → 15мин → 60мин)
- **`flutter_secure_storage`** для PIN, токенов и ключа шифрования Hive (Android: EncryptedSharedPreferences, iOS: Keychain)
- **Шифрование локальной БД** Hive с помощью случайного 256-битного ключа

### 🎨 Современный UI/UX
- **Material 3** дизайн-система, кастомная тема через `AppTheme`
- **Светлая и тёмная темы** — корректно сохраняются и применяются с первого кадра при рестарте приложения
- **Material 3 NavigationBar** с **glassmorphism** (`BackdropFilter` + blur)
- **Inter** typography через Google Fonts
- **Динамическое приветствие** — обновляется каждую минуту с эмоджи времени суток (☀️ утро, 🌤️ день, 🌆 вечер, 🌙 ночь)
- **Shimmer-скелетоны** во время загрузки данных
- **Empty states** с полезными подсказками
- **Haptic feedback** для PIN и важных действий
- **Кастомный фон** — пользователь может установить своё фото
- **Бесшовный splash** без белого flash при старте (бренд-цвета на нативном уровне)

---

## 🛠️ Технологический стек

| Категория | Технологии |
|---|---|
| **Framework** | Flutter 3.x · Dart 3.5+ |
| **State management** | [Provider](https://pub.dev/packages/provider) |
| **Локальная БД** | [Hive](https://pub.dev/packages/hive) · [hive_flutter](https://pub.dev/packages/hive_flutter) |
| **Безопасное хранилище** | [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) |
| **Графики** | [fl_chart](https://pub.dev/packages/fl_chart) · [syncfusion_flutter_charts](https://pub.dev/packages/syncfusion_flutter_charts) |
| **Анимации** | [animate_do](https://pub.dev/packages/animate_do) · [flutter_animate](https://pub.dev/packages/flutter_animate) · [lottie](https://pub.dev/packages/lottie) |
| **UI-помощники** | [shimmer](https://pub.dev/packages/shimmer) · [google_fonts](https://pub.dev/packages/google_fonts) · [flutter_svg](https://pub.dev/packages/flutter_svg) |
| **Сеть** | [http](https://pub.dev/packages/http) · [dio](https://pub.dev/packages/dio) |
| **OAuth/банки** | [webview_flutter](https://pub.dev/packages/webview_flutter) · [url_launcher](https://pub.dev/packages/url_launcher) |
| **Автоимпорт** | `telephony` (SMS), `notification_listener_service` (push), кастомные парсеры и дедупликатор |
| **Маркетдата** | [MOEX ISS API](https://iss.moex.com) (акции РФ), Yahoo Finance (зарубежные), Open Exchange Rates (валюты) |
| **Утилиты** | [intl](https://pub.dev/packages/intl) · [uuid](https://pub.dev/packages/uuid) · [crypto](https://pub.dev/packages/crypto) |

---

## 📂 Структура проекта

```
lib/
├── main.dart                  # Точка входа, инициализация Hive, темы, провайдеров
├── models/                    # Hive-модели: Account, Transaction, UserProfile, Investment, ...
├── providers/                 # ChangeNotifier-провайдеры (accounts, transactions, profile, ...)
├── services/                  # Бизнес-логика: Database, Security, Banks API, OAuth, ...
│   ├── sms_listener_service.dart       # Фоновое чтение банковских SMS
│   ├── sms_parser.dart                 # Парсер сумм/мерчантов из банковских сообщений
│   ├── push_listener_service.dart      # Импорт транзакций из push-уведомлений
│   ├── transaction_deduplicator.dart   # Fuzzy-дедупликация (SMS ∪ push)
│   ├── investment_api_service.dart     # MOEX/Yahoo + Hive-кеш каталога и свечей
│   └── logo_cache_service.dart         # Постоянный кеш иконок банков и эмитентов
├── screens/                   # Экраны UI
│   ├── home_screen.dart       # Главный + Material 3 NavigationBar с glassmorphism
│   ├── accounts_screen.dart   # Список счетов
│   ├── add_transaction_screen.dart
│   ├── calculators_screen.dart  # Ипотека, вклады, кредиты, сравнение банков
│   ├── investments_screen.dart  # Портфель + каталог инструментов
│   ├── profile_screen.dart    # Настройки, тема, PIN, кастомный фон
│   ├── pin_lock_screen.dart   # PIN с прогрессивной блокировкой
│   ├── bank_*_screen.dart     # Интеграция с банками
│   ├── drafts_screen.dart     # Очередь черновиков из SMS/push на подтверждение
│   └── ...
├── widgets/                   # Переиспользуемые виджеты
│   ├── account_card.dart      # Карточка счёта с динамическим градиентом по color
│   ├── stats_cards.dart       # Карточки доходы/расходы
│   ├── transaction_list.dart  # Список транзакций + ExpenseLegend
│   ├── expense_pie_chart.dart # Pie chart для расходов и доходов
│   ├── skeletons.dart         # Shimmer-скелетоны для загрузки
│   └── bank_logo.dart         # Логотипы банков через Clearbit + fallback
└── utils/
    ├── app_colors.dart        # AppColors + AppTheme (light/dark)
    ├── app_utils.dart         # Утилиты (форматирование, приветствие, ...)
    └── constants.dart         # Справочники категорий
```

---

## 🚀 Запуск

### Требования
- Flutter SDK ≥ 3.5
- Android Studio / Xcode для сборки под целевую платформу
- Подключённый эмулятор или физическое устройство

### Установка
```bash
git clone https://github.com/<ваш-логин>/coinsift_app.git
cd coinsift_app
flutter pub get
flutter run
```

### Полезные команды
```bash
flutter analyze              # Статический анализ кода
flutter test                 # Запуск тестов
flutter run --release        # Релизная сборка
flutter build apk            # Сборка APK (Android)
flutter build appbundle      # Сборка AAB для Google Play
flutter build ios            # Сборка под iOS (нужен macOS)
```

---

## 🎯 Архитектурные особенности

- **Hive с шифрованием** — все локальные данные (счета, транзакции, инвестиции, профиль) хранятся в зашифрованных Hive-боксах с ключом из `flutter_secure_storage`
- **Провайдер UserProfileProvider грузится в `create:`** провайдера — тема применяется с первого кадра, без задержки
- **Прогрессивная блокировка PIN** в `SecurityService` через `_lockoutSteps` — защита от brute force
- **Адаптивные цвета** через `Theme.of(context).colorScheme.onSurface` вместо хардкода — корректное отображение в обеих темах
- **Native splash** настроен на бренд-цвет (`@color/brand_splash`) — нет белого flash при старте на Android
- **Material 3 компоненты** — `NavigationBar`, `SegmentedButton`, `FilledButton`, `BottomSheet` с drag handle, `SnackBar` floating

---

## 🔒 Безопасность и приватность

- Все финансовые данные хранятся **только локально** на устройстве пользователя
- Облачная синхронизация отсутствует
- PIN хешируется через SHA-256 и хранится в системном Keychain/EncryptedSharedPreferences
- Логи `print()` заменены на `debugPrint()` — не попадают в release-сборку

---

## 📋 Дорожная карта

- [x] Автоимпорт транзакций из SMS и push-уведомлений
- [x] Fuzzy-дедупликация SMS ∪ push (юнит-покрытие в `test/transaction_deduplicator_test.dart`)
- [x] Постоянный Hive-кеш логотипов и каталога инвестиций (офлайн-first)
- [x] Sparkline-график по акциям (MOEX candles)
- [ ] Миграция на `go_router` для deep links и OAuth-callback
- [ ] Dynamic Color (Material You) — `dynamic_color` package, темы из обоев на Android 12+
- [ ] Биометрическая аутентификация (`local_auth`) как альтернатива PIN
- [ ] Облачный бэкап с end-to-end шифрованием
- [ ] Виджеты на главный экран Android/iOS
- [ ] Уведомления о превышении бюджета
- [ ] Экспорт в CSV/PDF
- [ ] Многовалютность с автоматической конвертацией
- [ ] Запуск тестов в CI (GitHub Actions)

---

## 🤝 Вклад в проект

Pull request'ы приветствуются. Перед коммитом убедитесь, что:

```bash
flutter analyze       # должен пройти без замечаний
flutter test          # все тесты должны проходить
dart format lib/      # код отформатирован
```

---

## 📄 Лицензия

Распространяется по лицензии **MIT**. Подробнее в файле [LICENSE](LICENSE).

---

<div align="center">

**Сделано с ❤️ на Flutter**

</div>
