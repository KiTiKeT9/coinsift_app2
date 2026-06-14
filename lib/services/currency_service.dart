import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/currency_rate.dart';

class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  static const String _apiUrl = 'https://open.er-api.com/v6/latest/';
  static const String _cacheBoxName = 'currency_rates_cache';

  List<CurrencyRate>? _cachedRates;
  DateTime? _lastFetch;

  List<CurrencyRate>? get cachedRates => _cachedRates;
  DateTime? get lastFetch => _lastFetch;

  static const List<String> supportedCurrencies = [
    'RUB', 'USD', 'EUR', 'GBP', 'CNY', 'JPY', 'CHF', 'KZT', 'BYN', 'AMD',
  ];

  /// Актуальные курсы на 14.06.2026 (fallback при отсутствии сети/кеша)
  static const Map<String, double> defaultRates = {
    'USD': 1,
    'RUB': 72.418564,
    'EUR': 0.864531,
    'GBP': 0.746107,
    'CNY': 6.781714,
    'JPY': 160.232666,
    'CHF': 0.796743,
    'KZT': 489.008549,
    'BYN': 2.754415,
    'AMD': 368.36683,
  };

  static const Map<String, String> currencyFlags = {
    'RUB': '🇷🇺', 'USD': '🇺🇸', 'EUR': '🇪🇺', 'GBP': '🇬🇧',
    'CNY': '🇨🇳', 'JPY': '🇯🇵', 'CHF': '🇨🇭', 'KZT': '🇰🇿',
    'BYN': '🇧🇾', 'AMD': '🇦🇲',
  };

  static String getFlag(String currency) => currencyFlags[currency] ?? '💱';

  Future<List<CurrencyRate>> fetchRates({String base = 'USD'}) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl$base'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>;
        final time = DateTime.tryParse(data['time_update']?.toString() ?? '') ?? DateTime.now();

        final list = supportedCurrencies
            .where((c) => rates.containsKey(c))
            .map((c) => CurrencyRate(
                  currency: c,
                  rate: (rates[c] as num).toDouble(),
                  baseCurrency: base,
                  lastUpdated: time,
                ))
            .toList();

        _cachedRates = list;
        _lastFetch = time;
        await _saveToCache(list, time);
        return list;
      }
    } catch (e) {
      debugPrint('CurrencyService fetch error: $e');
    }

    final cached = await _loadFromCache();
    if (cached != null && cached.isNotEmpty) return cached;

    // Fallback: встроенные курсы (актуальны на 14.06.2026)
    debugPrint('CurrencyService: using embedded default rates');
    final now = DateTime.now();
    _cachedRates = defaultRates.entries.map((e) => CurrencyRate(
      currency: e.key,
      rate: e.value,
      baseCurrency: 'USD',
      lastUpdated: now,
    )).toList();
    _lastFetch = now;
    await _saveToCache(_cachedRates!, now);
    return _cachedRates!;
  }

  Future<double?> convert(double amount, String from, String to) async {
    if (from == to) return amount;
    final rates = await fetchRates(base: from);
    final rate = rates.where((r) => r.currency == to).firstOrNull;
    return rate != null ? amount * rate.rate : null;
  }

  double? convertSync(double amount, String from, String to) {
    if (from == to) return amount;
    if (_cachedRates == null || _cachedRates!.isEmpty) {
      // Попробовать загрузить из кеша/дефолта
      _cachedRates = defaultRates.entries.map((e) => CurrencyRate(
        currency: e.key, rate: e.value, baseCurrency: 'USD', lastUpdated: DateTime.now(),
      )).toList();
      _lastFetch = DateTime.now();
    }
    if (to == 'USD') {
      final rate = _cachedRates!.where((r) => r.currency == from).firstOrNull;
      return rate != null ? amount / rate.rate : null;
    }
    if (from == 'USD') {
      final rate = _cachedRates!.where((r) => r.currency == to).firstOrNull;
      return rate != null ? amount * rate.rate : null;
    }
    final fromRate = _cachedRates!.where((r) => r.currency == from).firstOrNull;
    final toRate = _cachedRates!.where((r) => r.currency == to).firstOrNull;
    if (fromRate == null || toRate == null) return null;
    return amount / fromRate.rate * toRate.rate;
  }

  Future<void> _saveToCache(List<CurrencyRate> rates, DateTime time) async {
    try {
      final box = await Hive.openBox<CurrencyRate>(_cacheBoxName);
      await box.clear();
      for (final r in rates) {
        await box.put(r.currency, r);
      }
      await box.put('_meta_lastFetch', CurrencyRate(
        currency: '_meta', rate: time.millisecondsSinceEpoch.toDouble(),
        baseCurrency: '', lastUpdated: time,
      ));
    } catch (_) {}
  }

  Future<List<CurrencyRate>?> _loadFromCache() async {
    try {
      final box = await Hive.openBox<CurrencyRate>(_cacheBoxName);
      final meta = box.get('_meta_lastFetch');
      if (meta == null) return null;
      _lastFetch = DateTime.fromMillisecondsSinceEpoch(meta.rate.toInt());
      _cachedRates = box.values.where((r) => r.currency != '_meta').toList();
      return _cachedRates;
    } catch (_) {
      return null;
    }
  }
}
