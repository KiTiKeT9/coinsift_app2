import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/transaction.dart';
import '../models/bank_models.dart'; // Импортируем ConnectedBankInfo оттуда

/// Сервис для работы с Belink - универсальный агрегатор банков
/// Документация: https://belink.ru/developers/docs
class BelinkService {
  static const String _baseUrl = ApiConfig.BELINK_API_URL;
  static const String _clientId = ApiConfig.BELINK_CLIENT_ID;
  static const String _clientSecret = ApiConfig.BELINK_CLIENT_SECRET;
  static const String _redirectUri = ApiConfig.BELINK_REDIRECT_URI;

  static const String _prefsEnabledKey = 'belink_enabled';
  static const String _prefsTokenKey = 'belink_access_token';
  static const String _prefsRefreshTokenKey = 'belink_refresh_token';
  static const String _prefsTokenExpiryKey = 'belink_token_expiry';
  static const String _prefsConnectedBanksKey = 'belink_connected_banks';

  // ===== УПРАВЛЕНИЕ ВКЛЮЧЕНИЕМ =====

  /// Включён ли Belink
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsEnabledKey) ?? false;
  }

  /// Включить/выключить Belink
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabledKey, enabled);
    if (!enabled) {
      await disconnectAll();
    }
  }

  // ===== OAuth АВТОРИЗАЦИЯ =====

  /// Получить URL для OAuth авторизации
  static String getOAuthUrl(String bankCode) {
    return '$_baseUrl/oauth/authorize?'
        'client_id=$_clientId'
        '&redirect_uri=$_redirectUri'
        '&response_type=code'
        '&bank=$bankCode'
        '&scope=accounts transactions';
  }

  /// Обменять код авторизации на токен
  static Future<bool> exchangeCodeForToken(String authCode) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/oauth/token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'grant_type': 'authorization_code',
          'code': authCode,
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'redirect_uri': _redirectUri,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
          expiresIn: data['expires_in'] ?? 3600,
        );
        return true;
      }

      debugPrint('Belink token exchange error: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Ошибка обмена токена: $e');
      return false;
    }
  }

  /// Обновить access token используя refresh token
  static Future<bool> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_prefsRefreshTokenKey);

      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/oauth/token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': _clientId,
          'client_secret': _clientSecret,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'] ?? refreshToken,
          expiresIn: data['expires_in'] ?? 3600,
        );
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Ошибка обновления токена: $e');
      return false;
    }
  }

  /// Проверка авторизации
  static Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_prefsTokenKey);
    final expiry = prefs.getString(_prefsTokenExpiryKey);

    if (token == null || expiry == null) return false;

    final expiryDate = DateTime.parse(expiry);
    if (DateTime.now().isAfter(expiryDate)) {
      // Токен истёк, пробуем обновить
      final refreshed = await refreshToken();
      return refreshed;
    }

    return true;
  }

  /// Получить access token
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsTokenKey);
  }

  /// Сохранить токены
  static Future<void> _saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsTokenKey, accessToken);
    await prefs.setString(_prefsRefreshTokenKey, refreshToken);
    await prefs.setString(
      _prefsTokenExpiryKey,
      DateTime.now().add(Duration(seconds: expiresIn)).toIso8601String(),
    );
  }

  // ===== УПРАВЛЕНИЕ ПОДКЛЮЧЁННЫМИ БАНКАМИ =====

  /// Получить список подключённых банков
  static Future<List<ConnectedBankInfo>> getConnectedBanks() async {
    final prefs = await SharedPreferences.getInstance();
    final banksJson = prefs.getStringList(_prefsConnectedBanksKey) ?? [];

    return banksJson
        .map((json) => ConnectedBankInfo.fromJson(jsonDecode(json)))
        .toList();
  }

  /// Добавить подключённый банк
  static Future<void> addConnectedBank(ConnectedBankInfo bank) async {
    final prefs = await SharedPreferences.getInstance();
    final banks = await getConnectedBanks();

    banks.removeWhere((b) => b.bankId == bank.bankId);
    banks.add(bank);

    await prefs.setStringList(
      _prefsConnectedBanksKey,
      banks.map((b) => jsonEncode(b.toJson())).toList(),
    );
  }

  /// Удалить подключённый банк
  static Future<void> removeConnectedBank(String bankId) async {
    final prefs = await SharedPreferences.getInstance();
    final banks = await getConnectedBanks();

    banks.removeWhere((b) => b.bankId == bankId);

    await prefs.setStringList(
      _prefsConnectedBanksKey,
      banks.map((b) => jsonEncode(b.toJson())).toList(),
    );

    // Также отзываем токен на сервере
    await _revokeBankToken(bankId);
  }

  /// Отключить все банки
  static Future<void> disconnectAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsConnectedBanksKey);
    await prefs.remove(_prefsTokenKey);
    await prefs.remove(_prefsRefreshTokenKey);
    await prefs.remove(_prefsTokenExpiryKey);
  }

  /// Отозвать токен банка на сервере
  static Future<void> _revokeBankToken(String bankId) async {
    final token = await getAccessToken();
    if (token == null) return;

    try {
      await http.post(
        Uri.parse('$_baseUrl/oauth/revoke'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'bank_id': bankId}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Ошибка отзыва токена: $e');
    }
  }

  // ===== ПОЛУЧЕНИЕ ДАННЫХ =====

  /// Получить все счета из всех подключённых банков
  static Future<List<BelinkAccount>> getAccounts() async {
    final token = await getAccessToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/accounts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accounts = data['accounts'] as List;

        return accounts.map((acc) => BelinkAccount.fromJson(acc)).toList();
      }

      debugPrint('Belink get accounts error: ${response.body}');
      return [];
    } catch (e) {
      debugPrint('Ошибка получения счетов: $e');
      return [];
    }
  }

  /// Получить транзакции по счёту
  static Future<List<Transaction>> getTransactions({
    required String accountId,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    final token = await getAccessToken();
    if (token == null) return [];

    from ??= DateTime.now().subtract(const Duration(days: 30));
    to ??= DateTime.now();

    try {
      final url = '$_baseUrl/accounts/$accountId/transactions?'
          'from=${from.toIso8601String()}'
          '&to=${to.toIso8601String()}'
          '&limit=$limit';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final transactions = data['transactions'] as List;

        return transactions
            .map((tx) => _parseTransaction(tx, accountId))
            .where((tx) => tx != null)
            .cast<Transaction>()
            .toList();
      }

      debugPrint('Belink get transactions error: ${response.body}');
      return [];
    } catch (e) {
      debugPrint('Ошибка получения транзакций: $e');
      return [];
    }
  }

  /// Получить транзакции из всех банков
  static Future<List<Transaction>> getAllTransactions({int days = 30}) async {
    final accounts = await getAccounts();
    final allTransactions = <Transaction>[];

    for (final account in accounts) {
      final transactions = await getTransactions(
        accountId: account.id,
        from: DateTime.now().subtract(Duration(days: days)),
      );
      allTransactions.addAll(transactions);
    }

    return allTransactions;
  }

  /// Парсинг транзакции из ответа API
  static Transaction? _parseTransaction(Map<String, dynamic> tx, String accountId) {
    try {
      final amount = (tx['amount'] ?? 0).toDouble();
      final dateStr = tx['date'] ?? tx['created_at'];

      return Transaction(
        id: tx['id'] ?? 'tx_${DateTime.now().millisecondsSinceEpoch}',
        accountId: accountId,
        amount: amount.abs(),
        category: _mapCategory(tx['category'] ?? tx['merchant'] ?? ''),
        description: tx['description'] ?? tx['merchant'] ?? 'Транзакция',
        date: dateStr != null ? DateTime.parse(dateStr) : DateTime.now(),
        type: amount > 0 ? 'income' : 'expense',
        currency: tx['currency'] ?? 'RUB',
        merchantName: tx['merchant'],
      );
    } catch (e) {
      debugPrint('Ошибка парсинга транзакции: $e');
      return null;
    }
  }

  /// Маппинг категорий из Belink
  static String _mapCategory(String category) {
    final lower = category.toLowerCase();

    if (lower.contains('продукт') || lower.contains('grocery') ||
        lower.contains('супермаркет') || lower.contains('магнит') ||
        lower.contains('пятёрочк') || lower.contains('перекрёсток')) {
      return 'Продукты';
    }

    if (lower.contains('ресторан') || lower.contains('кафе') ||
        lower.contains('restaurant') || lower.contains('мcdonald')) {
      return 'Рестораны';
    }

    if (lower.contains('транспорт') || lower.contains('метро') ||
        lower.contains('автобус') || lower.contains('tram')) {
      return 'Транспорт';
    }

    if (lower.contains('такси') || lower.contains('yandex') ||
        lower.contains('uber') || lower.contains('ситимобил')) {
      return 'Такси';
    }

    if (lower.contains('развлечен') || lower.contains('кино') ||
        lower.contains('entertainment')) {
      return 'Развлечения';
    }

    if (lower.contains('здоров') || lower.contains('аптек') ||
        lower.contains('медицин') || lower.contains('pharmacy')) {
      return 'Здоровье';
    }

    if (lower.contains('одежд') || lower.contains('clothing')) {
      return 'Одежда';
    }

    if (lower.contains('зарплат') || lower.contains('salary') ||
        lower.contains('зачисление')) {
      return 'Зарплата';
    }

    if (lower.contains('инвестиц') || lower.contains('дивиденд') ||
        lower.contains('broker')) {
      return 'Инвестиции';
    }

    return 'Другое';
  }

  // ===== ДЕМО РЕЖИМ (для тестирования без реального API) =====

  static Future<List<BelinkAccount>> getDemoAccounts() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      BelinkAccount(
        id: 'demo_tinkoff_1',
        bankId: 'tinkoff',
        bankName: 'Тинькофф',
        name: 'Брокерский счёт',
        balance: 125430.50,
        currency: 'RUB',
        type: 'investment',
        number: '****1234',
      ),
      BelinkAccount(
        id: 'demo_sber_1',
        bankId: 'sber',
        bankName: 'Сбербанк',
        name: 'Дебетовая карта',
        balance: 45600.00,
        currency: 'RUB',
        type: 'checking',
        number: '****5678',
      ),
      BelinkAccount(
        id: 'demo_alfa_1',
        bankId: 'alfa',
        bankName: 'Альфа-Банк',
        name: 'Кредитная карта',
        balance: 12300.00,
        currency: 'RUB',
        type: 'credit',
        number: '****9012',
      ),
    ];
  }

  static Future<List<Transaction>> getDemoTransactions() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      Transaction(
        id: 'demo_tx_1',
        accountId: 'demo_tinkoff_1',
        amount: 3250.00,
        category: 'Продукты',
        description: 'Пятёрочка',
        date: DateTime.now().subtract(const Duration(hours: 2)),
        type: 'expense',
      ),
      Transaction(
        id: 'demo_tx_2',
        accountId: 'demo_sber_1',
        amount: 50000.00,
        category: 'Зарплата',
        description: 'Зачисление зарплаты',
        date: DateTime.now().subtract(const Duration(days: 1)),
        type: 'income',
      ),
      Transaction(
        id: 'demo_tx_3',
        accountId: 'demo_tinkoff_1',
        amount: 850.00,
        category: 'Рестораны',
        description: 'Яндекс Еда',
        date: DateTime.now().subtract(const Duration(days: 2)),
        type: 'expense',
      ),
      Transaction(
        id: 'demo_tx_4',
        accountId: 'demo_alfa_1',
        amount: 1200.00,
        category: 'Транспорт',
        description: 'Метро',
        date: DateTime.now().subtract(const Duration(days: 3)),
        type: 'expense',
      ),
    ];
  }
}

// Класс ConnectedBankInfo удален из этого файла, так как определен в bank_models.dart

/// Модель счёта из Belink
class BelinkAccount {
  final String id;
  final String bankId;
  final String bankName;
  final String name;
  final double balance;
  final String currency;
  final String type;
  final String number;

  BelinkAccount({
    required this.id,
    required this.bankId,
    required this.bankName,
    required this.name,
    required this.balance,
    required this.currency,
    required this.type,
    required this.number,
  });

  factory BelinkAccount.fromJson(Map<String, dynamic> json) => BelinkAccount(
    id: json['id'] ?? '',
    bankId: json['bank_id'] ?? '',
    bankName: json['bank_name'] ?? '',
    name: json['name'] ?? 'Счёт',
    balance: (json['balance'] ?? 0).toDouble(),
    currency: json['currency'] ?? 'RUB',
    type: json['type'] ?? 'checking',
    number: json['number'] ?? '',
  );

  String get typeLabel {
    switch (type) {
      case 'checking':
        return 'Расчётный';
      case 'savings':
        return 'Накопительный';
      case 'credit':
        return 'Кредитный';
      case 'investment':
        return 'Инвестиционный';
      case 'deposit':
        return 'Депозит';
      default:
        return type;
    }
  }
}