# 🏦 Настройка Belink - Агрегатор банковских API

Этот документ описывает пошаговый процесс настройки интеграции с **Belink** - универсальным агрегатором банковских API для России.

---

## 📋 Что такое Belink?

**Belink** - это сервис-агрегатор, который предоставляет единый API для работы с множеством банков:
- ✅ Тинькофф
- ✅ Сбербанк  
- ✅ Альфа-Банк
- ✅ ВТБ
- ✅ Райффайзен
- И другие

**Преимущества:**
- 🎯 Одна интеграция = много банков
- 🔒 Безопасно - вы не храните логины/пароли
- 📊 Все данные в одном месте
- 🔄 Автоматическое обновление транзакций

---

## 🚀 Пошаговая инструкция

### Шаг 1: Регистрация в Belink

1. **Перейдите на сайт разработчиков:**
   ```
   https://belink.ru/developers
   ```

2. **Нажмите "Зарегистрироваться"**

3. **Заполните форму:**
   - Email
   - Пароль
   - Имя/Название компании

4. **Подтвердите email** (придёт письмо на почту)

---

### Шаг 2: Создание приложения

1. **Войдите в личный кабинет:**
   ```
   https://belink.ru/developers/dashboard
   ```

2. **Нажмите кнопку "Создать приложение"**

3. **Заполните форму:**

   | Поле | Значение |
   |------|----------|
   | Название приложения | `Монетка` |
   | Описание | `Приложение для учёта личных финансов` |
   | Тип приложения | `Мобильное приложение` |
   | Platform | `Flutter (Android/iOS)` |
   | Redirect URI | `monetka://belink-callback` |

4. **Нажмите "Создать"**

5. **Скопируйте полученные ключи:**
   - `Client ID` (например: `cl_abc123def456`)
   - `Client Secret` (например: `cs_xyz789uvw012`)

---

### Шаг 3: Настройка в приложении

1. **Откройте файл конфигурации:**
   ```
   lib/config/api_config.dart
   ```

2. **Замените константы на ваши значения:**

   ```dart
   // БЫЛО:
   static const String BELINK_CLIENT_ID = 'your_client_id_here';
   static const String BELINK_CLIENT_SECRET = 'your_client_secret_here';
   
   // СТАЛО (подставьте ваши ключи):
   static const String BELINK_CLIENT_ID = 'cl_abc123def456';
   static const String BELINK_CLIENT_SECRET = 'cs_xyz789uvw012';
   ```

3. **Выберите режим:**

   ```dart
   // true - Sandbox режим (для тестирования, БЕСПЛАТНО)
   // false - Production режим (реальные данные)
   static const bool BELINK_USE_SANDBOX = true;
   ```

4. **Сохраните файл**

---

### Шаг 4: Тестирование (Sandbox режим)

1. **Запустите приложение:**
   ```bash
   flutter run
   ```

2. **Перейдите в:**
   ```
   Профиль → Банковские интеграции → Агрегатор банков
   ```

3. **Включите переключатель "Включить агрегатор"**

4. **Выберите банк для подключения** (например, Тинькофф)

5. **Нажмите "Подключить"**

6. **Авторизуйтесь через WebView:**
   - В Sandbox режиме откроется тестовая страница
   - Введите тестовые данные (предоставляются Belink)

7. **После успешной авторизации:**
   - ✅ Появятся счета банка
   - ✅ Появятся тестовые транзакции
   - ✅ Можно подключить ещё один банк

---

### Шаг 5: Production режим (реальные данные)

> ⚠️ **Важно:** Перед переходом в production убедитесь, что всё работает в Sandbox!

1. **Измените режим в конфигурации:**
   ```dart
   static const bool BELINK_USE_SANDBOX = false;
   ```

2. **Измените URL API:**
   ```dart
   static const String BELINK_API_URL = 'https://api.belink.ru/v1';
   ```

3. **Пересоберите приложение:**
   ```bash
   flutter build apk --release
   ```

4. **Теперь при подключении:**
   - Откроется РЕАЛЬНАЯ страница банка
   - Пользователь вводит свои реальные логин/пароль
   - Belink получает доступ к реальным данным
   - Транзакции синхронизируются автоматически

---

## 📊 API Endpoints

### OAuth авторизация
```
GET {BASE_URL}/oauth/authorize?
    client_id={CLIENT_ID}
    &redirect_uri={REDIRECT_URI}
    &response_type=code
    &bank={BANK_CODE}
    &scope=accounts transactions
```

### Обмен кода на токен
```
POST {BASE_URL}/oauth/token
{
  "grant_type": "authorization_code",
  "code": "{AUTH_CODE}",
  "client_id": "{CLIENT_ID}",
  "client_secret": "{CLIENT_SECRET}",
  "redirect_uri": "{REDIRECT_URI}"
}
```

### Получение счетов
```
GET {BASE_URL}/accounts
Authorization: Bearer {ACCESS_TOKEN}
```

### Получение транзакций
```
GET {BASE_URL}/accounts/{ACCOUNT_ID}/transactions?from=2024-01-01&to=2024-04-01&limit=100
Authorization: Bearer {ACCESS_TOKEN}
```

---

## 🔧 Troubleshooting

### Проблема: "Invalid client_id"
**Решение:** Проверьте что Client ID правильно скопирован из личного кабинета

### Проблема: "Redirect URI mismatch"
**Решение:** Убедитесь что Redirect URI в приложении совпадает с настройками в Belink:
- В приложении: `monetka://belink-callback`
- В Belink Dashboard: `monetka://belink-callback`

### Проблема: "Token expired"
**Решение:** Сервис автоматически обновляет токен. Если проблема сохраняется - переподключите банк

### Проблема: Нет транзакций
**Решение:**
1. Проверьте что банк подключён (зелёная галочка)
2. Нажмите "Обновить все"
3. Проверьте логи в консоли: `flutter run --verbose`

---

## 💰 Тарифы Belink

### Sandbox (Бесплатно)
- ✅ Тестовые данные
- ✅ До 3 банков
- ✅ 100 запросов/день
- ❌ Нет реальных данных

### Basic (990₽/мес)
- ✅ Реальные данные
- ✅ До 5 банков
- ✅ 1000 запросов/день
- ✅ Email поддержка

### Pro (2990₽/мес)
- ✅ Реальные данные
- ✅ Безлимит банков
- ✅ 10000 запросов/день
- ✅ Приоритетная поддержка
- ✅ Webhook уведомления

### Enterprise (по договорённости)
- ✅ Всё из Pro
- ✅ Выделенный сервер
- ✅ SLA 99.9%
- ✅ Персональный менеджер

---

## 📞 Поддержка

- **Документация:** https://belink.ru/developers/docs
- **Email:** developers@belink.ru
- **Telegram:** @belink_dev_support
- **Форум:** https://community.belink.ru

---

## 🔗 Ссылки

- Belink Developer Portal: https://belink.ru/developers
- API Documentation: https://belink.ru/developers/docs
- Sandbox Dashboard: https://sandbox.belink.ru/dashboard
- Status Page: https://status.belink.ru

---

## ✅ Чек-лист настройки

- [ ] Зарегистрировались на belink.ru/developers
- [ ] Создали приложение "Монетка"
- [ ] Скопировали Client ID
- [ ] Скопировали Client Secret  
- [ ] Вставили ключи в `api_config.dart`
- [ ] Настроили Redirect URI: `monetka://belink-callback`
- [ ] Протестировали в Sandbox режиме
- [ ] Подключили хотя бы 1 банк
- [ ] Убедились что транзакции отображаются
- [ ] (Опционально) Перешли в Production режим

---

**Готово!** 🎉 Теперь ваше приложение может получать данные из нескольких банков через один интерфейс!
