import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Сервис для работы с Tinkoff Open API
/// Документация: https://www.tinkoff.ru/invest/open-api/
class TinkoffApiService {
  // Sandbox URL для тестирования
  static const String _baseUrl = 'https://sandbox-invest.tinkoff.ru/api/v3';
  // Production URL (раскомментировать для реального использования)
  // static const String _baseUrl = 'https://invest.tinkoff.ru/api/v3';

  static const String _prefsKey = 'tinkoff_enabled';
  static const String _tokenKey = 'tinkoff_access_token';
  static const String _tokenExpiryKey = 'tinkoff_token_expiry';

  /// Включён ли Tinkoff API
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  /// Включить/выключить Tinkoff API
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
    if (!enabled) {
      await prefs.remove(_tokenKey);
      await prefs.remove(_tokenExpiryKey);
    }
  }

  /// Проверка авторизации
  static Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final expiry = prefs.getString(_tokenExpiryKey);
    
    if (token == null || expiry == null) return false;
    
    // Проверяем не истёк ли токен
    final expiryDate = DateTime.parse(expiry);
    return DateTime.now().isBefore(expiryDate);
  }

  /// Сохранение токена
  static Future<void> saveToken(String token, {int expiresIn = 3600}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(
      _tokenExpiryKey,
      DateTime.now().add(Duration(seconds: expiresIn)).toIso8601String(),
    );
  }

  /// Получение токена
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Удаление токена
  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenExpiryKey);
  }

  /// Получение счетов пользователя
  static Future<List<TinkoffAccount>> getAccounts() async {
    final token = await getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/accounts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accounts = data['accounts'] as List;
        
        return accounts.map((acc) => TinkoffAccount(
          id: acc['id'] ?? '',
          name: acc['name'] ?? 'Счёт',
          type: acc['openedAccountType'] ?? 'TinkoffInvest',
          currency: acc['currency'] ?? 'rub',
          balance: _parseBalance(acc),
        )).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Ошибка получения счетов: $e');
      return [];
    }
  }

  /// Получение операций по счёту
  static Future<List<TinkoffOperation>> getOperations({
    required String accountId,
    DateTime? from,
    DateTime? to,
  }) async {
    final token = await getToken();
    if (token == null) return [];

    from ??= DateTime.now().subtract(const Duration(days: 30));
    to ??= DateTime.now();

    try {
      final url = '$_baseUrl/operations?'
          'accountId=$accountId'
          '&from=${from.toIso8601String()}'
          '&to=${to.toIso8601String()}';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final operations = data['operations'] as List;
        
        return operations.map((op) => TinkoffOperation(
          id: op['id'] ?? '',
          date: DateTime.parse(op['date'] ?? DateTime.now().toIso8601String()),
          description: op['name'] ?? op['text'] ?? 'Операция',
          amount: (op['payment']?['value'] ?? 0).toDouble(),
          currency: op['payment']?['currency'] ?? 'rub',
          category: _mapCategory(op['name'] ?? ''),
          type: _parseOperationType(op),
        )).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Ошибка получения операций: $e');
      return [];
    }
  }

  /// Получение портфеля (ценные бумаги)
  static Future<List<TinkoffPortfolio>> getPortfolio(String accountId) async {
    final token = await getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/operations/positions?accountId=$accountId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final positions = data['positions'] as List;
        
        return positions.map((pos) => TinkoffPortfolio(
          ticker: pos['ticker'] ?? '',
          name: pos['name'] ?? pos['figi'] ?? '',
          quantity: (pos['balance'] ?? 0).toDouble(),
          averagePrice: (pos['averagePositionPrice']?['value'] ?? 0).toDouble(),
          currentPrice: (pos['expectedYield']?['value'] ?? 0).toDouble(),
          currency: pos['currency'] ?? 'rub',
        )).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Ошибка получения портфеля: $e');
      return [];
    }
  }

  /// Парсинг баланса из ответа API
  static double _parseBalance(Map<String, dynamic> account) {
    final portfolio = account['portfolio'];
    if (portfolio != null) {
      return (portfolio['totalAmountPortfolio']?['value'] ?? 0).toDouble();
    }
    return (account['balance'] ?? 0).toDouble();
  }

  /// Определение типа операции
  static String _parseOperationType(Map<String, dynamic> op) {
    final amount = (op['payment']?['value'] ?? 0).toDouble();
    return amount > 0 ? 'income' : 'expense';
  }

  /// Маппинг категорий из Tinkoff
  static String _mapCategory(String name) {
    final lowerName = name.toLowerCase();

    if (lowerName.contains('дивиденд')) return 'Инвестиции';
    if (lowerName.contains('купон')) return 'Инвестиции';
    if (lowerName.contains('покупк')) return 'Инвестиции';
    if (lowerName.contains('продаж')) return 'Инвестиции';
    if (lowerName.contains('зачислен')) return 'Зарплата';
    if (lowerName.contains('перевод')) return 'Переводы';
    if (lowerName.contains('списан')) return 'Другое';
    
    return 'Другое';
  }

  /// URL для OAuth авторизации
  /// Замените clientId на ваш реальный client_id из Tinkoff
  static String getOAuthUrl({String clientId = 'your_client_id'}) {
    return 'https://www.tinkoff.ru/invest/open-api/auth/?'
        'client_id=$clientId'
        '&response_type=code'
        '&redirect_uri=coinsift://tinkoff-callback'
        '&state=coinsift_tinkoff_auth';
  }

  /// Обработка callback с кодом авторизации
  /// Получаем код из redirect URI и обмениваем на токен
  static Future<bool> handleAuthCode(String authCode, {String clientId = 'your_client_id', String clientSecret = 'your_client_secret'}) async {
    try {
      // В реальном приложении здесь был бы запрос к серверу для обмена кода на токен
      // Т.к. client_secret нельзя хранить в приложении
      
      // Для демонстрации сохраняем код как токен
      await saveToken('demo_token_$authCode', expiresIn: 86400);
      return true;
    } catch (e) {
      debugPrint('Ошибка авторизации: $e');
      return false;
    }
  }

  /// Отключение Tinkoff
  static Future<void> disconnect() async {
    await removeToken();
    await setEnabled(false);
  }

  /// Получить демо-данные для тестирования
  static Future<List<TinkoffAccount>> getDemoAccounts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    return [
      TinkoffAccount(
        id: 'demo_account_1',
        name: 'Брокерский счёт',
        type: 'TinkoffInvest',
        currency: 'rub',
        balance: 125430.50,
      ),
      TinkoffAccount(
        id: 'demo_account_2',
        name: 'ИИС',
        type: 'TinkoffIis',
        currency: 'rub',
        balance: 89200.00,
      ),
    ];
  }

  /// Получить демо-операции для тестирования
  static Future<List<TinkoffOperation>> getDemoOperations({String accountId = 'demo_account_1'}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    return [
      TinkoffOperation(
        id: 'op_1',
        date: DateTime.now().subtract(const Duration(days: 1)),
        description: 'Покупка SBER',
        amount: -32500.00,
        currency: 'rub',
        category: 'Инвестиции',
        type: 'expense',
      ),
      TinkoffOperation(
        id: 'op_2',
        date: DateTime.now().subtract(const Duration(days: 2)),
        description: 'Дивиденды GAZP',
        amount: 1850.00,
        currency: 'rub',
        category: 'Инвестиции',
        type: 'income',
      ),
      TinkoffOperation(
        id: 'op_3',
        date: DateTime.now().subtract(const Duration(days: 5)),
        description: 'Пополнение счёта',
        amount: 50000.00,
        currency: 'rub',
        category: 'Зарплата',
        type: 'income',
      ),
      TinkoffOperation(
        id: 'op_4',
        date: DateTime.now().subtract(const Duration(days: 7)),
        description: 'Продажа LKOH',
        amount: 78900.00,
        currency: 'rub',
        category: 'Инвестиции',
        type: 'income',
      ),
    ];
  }
}

/// Модель счёта Tinkoff
class TinkoffAccount {
  final String id;
  final String name;
  final String type;
  final String currency;
  final double balance;

  TinkoffAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.balance,
  });

  String get typeLabel {
    switch (type) {
      case 'TinkoffInvest':
        return 'Брокерский';
      case 'TinkoffIis':
        return 'ИИС';
      default:
        return type;
    }
  }
}

/// Модель операции Tinkoff
class TinkoffOperation {
  final String id;
  final DateTime date;
  final String description;
  final double amount;
  final String currency;
  final String category;
  final String type;

  TinkoffOperation({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.currency,
    required this.category,
    required this.type,
  });
}

/// Модель позиции портфеля
class TinkoffPortfolio {
  final String ticker;
  final String name;
  final double quantity;
  final double averagePrice;
  final double currentPrice;
  final String currency;

  TinkoffPortfolio({
    required this.ticker,
    required this.name,
    required this.quantity,
    required this.averagePrice,
    required this.currentPrice,
    required this.currency,
  });

  double get totalValue => quantity * currentPrice;
  double get profitLoss => totalValue - (quantity * averagePrice);
  double get profitLossPercent => averagePrice != 0 
      ? ((currentPrice - averagePrice) / averagePrice) * 100 
      : 0;
}
