import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import '../models/investment_instrument.dart';

/// Сервис для получения данных об инвестициях через различные API
class InvestmentApiService {
  static const String _moexBaseUrl = 'https://iss.moex.com/iss';
  static const String _openExchangeRatesUrl = 'https://open.er-api.com/v6/latest';
  static const String _yahooFinanceProxyUrl = 'https://query1.finance.yahoo.com/v8/finance/chart';

  /// Получение текущей цены акции через MOEX API
  /// ticker - тикер акции (например, SBER, GAZP, YNDX)
  /// board - тип рынка (TQBR для основного режима акций)
  static Future<double?> getMoexPrice(String ticker, {String board = 'TQBR'}) async {
    try {
      final url = '$_moexBaseUrl/engines/stock/markets/shares/boards/$board/securities/$ticker.json';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Получаем данные из marketdata
        final marketdata = data['marketdata'];
        if (marketdata != null && marketdata['data'] != null && marketdata['data'].isNotEmpty) {
          final columns = marketdata['columns'];
          final marketData = marketdata['data'][0];
          
          // Ищем цену последней сделки (LAST)
          final lastPriceIndex = columns.indexOf('LAST');
          if (lastPriceIndex != -1 && marketData[lastPriceIndex] != null) {
            return (marketData[lastPriceIndex] as num).toDouble();
          }
          
          // Если LAST нет, пробуем цену закрытия (CLOSE)
          final closePriceIndex = columns.indexOf('CLOSE');
          if (closePriceIndex != -1 && marketData[closePriceIndex] != null) {
            return (marketData[closePriceIndex] as num).toDouble();
          }
          
          // Если и её нет, пробуем цену последней сделки к открытию (OPEN)
          final openPriceIndex = columns.indexOf('OPEN');
          if (openPriceIndex != -1 && marketData[openPriceIndex] != null) {
            return (marketData[openPriceIndex] as num).toDouble();
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Ошибка получения данных MOEX для $ticker: $e');
      return null;
    }
  }

  /// Получение цены зарубежной акции через Yahoo Finance API
  /// ticker - тикер акции (например, AAPL, GOOGL, TSLA)
  static Future<Map<String, dynamic>?> getForeignStockPrice(String ticker) async {
    try {
      final url = '$_yahooFinanceProxyUrl/$ticker?interval=1d&range=1d';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['chart']['result'];
        
        if (result != null && result.isNotEmpty) {
          final firstResult = result[0];
          final meta = firstResult['meta'];
          
          if (meta != null) {
            final currentPrice = meta['regularMarketPrice'];
            final currency = meta['currency'] ?? 'USD';
            final marketState = meta['marketState'] ?? 'CLOSED';
            
            if (currentPrice != null) {
              return {
                'price': (currentPrice as num).toDouble(),
                'currency': currency,
                'marketState': marketState,
              };
            }
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Ошибка получения данных Yahoo Finance для $ticker: $e');
      return null;
    }
  }

  /// Получение информации о ценной бумаге через MOEX API
  static Future<Map<String, dynamic>?> getMoexSecurityInfo(String ticker, {String board = 'TQBR'}) async {
    try {
      final url = '$_moexBaseUrl/engines/stock/markets/shares/boards/$board/securities/$ticker.json';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final securities = data['secid'];
        if (securities != null && securities['data'] != null && securities['data'].isNotEmpty) {
          final columns = securities['columns'];
          final securityData = securities['data'][0];
          
          return {
            for (int i = 0; i < columns.length; i++)
              columns[i]: securityData[i]
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('Ошибка получения информации MOEX для $ticker: $e');
      return null;
    }
  }

  /// Получение курса валюты через Open Exchange Rates API
  /// baseCurrency - базовая валюта (USD, EUR, etc.)
  static Future<double?> getExchangeRate(String baseCurrency, {String targetCurrency = 'RUB'}) async {
    try {
      final response = await http.get(Uri.parse('$_openExchangeRatesUrl/$baseCurrency')).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'];
        
        if (rates != null && rates[targetCurrency] != null) {
          return (rates[targetCurrency] as num).toDouble();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Ошибка получения курса валюты $baseCurrency: $e');
      return null;
    }
  }

  /// Получение цен для списка тикеров
  /// Возвращает Map {ticker: price}
  static Future<Map<String, double>> getMultiplePrices(List<String> tickers) async {
    final Map<String, double> prices = {};
    
    for (final ticker in tickers) {
      if (isRussianTicker(ticker)) {
        // Российские акции через MOEX
        final price = await getMoexPrice(ticker);
        if (price != null) {
          prices[ticker.toUpperCase()] = price;
        }
      } else {
        // Зарубежные акции через Yahoo Finance
        final data = await getForeignStockPrice(ticker);
        if (data != null) {
          prices[ticker.toUpperCase()] = (data['price'] as num).toDouble();
        }
      }
    }
    
    return prices;
  }

  /// Универсальный метод получения цены для любого тикера
  static Future<double?> getPrice(String ticker) async {
    if (isRussianTicker(ticker)) {
      return await getMoexPrice(ticker);
    } else {
      final data = await getForeignStockPrice(ticker);
      return data != null ? (data['price'] as num).toDouble() : null;
    }
  }

  /// Определение типа тикера (российский или зарубежный)
  static bool isRussianTicker(String ticker) {
    if (ticker.isEmpty) return false;
    
    // Список популярных российских тикеров, торгующихся на MOEX
    final russianTickers = [
      'SBER', 'GAZP', 'LKOH', 'GMKN', 'YNDX', 'MGNT', 'NVTK', 'ROSN',
      'VTBR', 'AFLT', 'AFKS', 'MTSS', 'MGMT', 'PLZL', 'ALRS', 'CHMF',
      'NLMK', 'MAGN', 'SNGS', 'TATN', 'BSPB', 'MOEX', 'PIKK', 'MTLR',
      'RUAL', 'POLY', 'RSTI', 'UPRO', 'SELG', 'TCSG', 'OZON', 'VKCO',
      'SBERP', 'GAZPM', 'SNGSP', 'TATNP', 'LKOP', 'AFLTP',
      // Облигации и фонды
      'SBERB', 'VTBB', 'GAZPB',
      // Дополнительные тикеры
      'BANEP', 'CBOM', 'FEES', 'HYDR', 'IRAO', 'KMAZ', 'KOGK', 'KRKNP',
      'LSNG', 'LSRGP', 'MFGS', 'MRSB', 'MSNG', 'MSTT', 'MTLRP', 'NKHP',
      'NKNC', 'NKNCP', 'NMTP', 'OGKB', 'OKEY', 'PHOR', 'PRMB', 'RAVN',
      'RBCM', 'RCMR', 'RGSS', 'RDRB', 'RDRBP', 'RTKM', 'RTKMP', 'SBPR',
      'SIBN', 'STSB', 'TGKA', 'TGKBP', 'TGMN', 'TLKH', 'TRMK', 'TRNFP',
      'UKUZ', 'UNAC', 'UPRO', 'URKZ', 'URKA', 'USBN', 'VSMO', 'YAKG',
      'YKSAP', 'YNDX', 'ZVEZ',
    ];
    
    return russianTickers.contains(ticker.toUpperCase());
  }

  /// Получение данных для популярных ETF
  static Future<Map<String, dynamic>?> getEtfInfo(String ticker) async {
    try {
      // Для российских ETF можно использовать MOEX
      if (ticker.endsWith('.ME') || ticker.endsWith('.P')) {
        final cleanTicker = ticker.replaceAll('.ME', '').replaceAll('.P', '');
        final price = await getMoexPrice(cleanTicker);
        if (price != null) {
          return {'price': price, 'currency': 'RUB'};
        }
      }
      
      // Для зарубежных ETF используем Yahoo Finance
      final data = await getForeignStockPrice(ticker);
      return data;
    } catch (e) {
      debugPrint('Ошибка получения информации об ETF $ticker: $e');
      return null;
    }
  }

  /// Имя Hive-бокса с закешированным каталогом инструментов и ценами.
  /// Заполняется в [getPopularInstruments] и возвращается, когда MOEX
  /// недоступен (таймаут/сетевая ошибка), чтобы пользователь не видел
  /// пустой экран.
  static const String _catalogBoxName = 'investment_catalog';
  static const String _catalogKey = 'popular';

  static Future<Box<dynamic>?> _openCatalogBox() async {
    try {
      if (Hive.isBoxOpen(_catalogBoxName)) {
        return Hive.box<dynamic>(_catalogBoxName);
      }
      return await Hive.openBox<dynamic>(_catalogBoxName);
    } catch (e) {
      debugPrint('Не удалось открыть catalog box: $e');
      return null;
    }
  }

  static List<InvestmentInstrument> _decodeCachedCatalog(dynamic raw) {
    if (raw is! List) return const [];
    final result = <InvestmentInstrument>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final ticker = item['ticker'];
      final name = item['name'];
      final type = item['type'];
      if (ticker is! String || name is! String || type is! String) continue;
      result.add(InvestmentInstrument(
        ticker: ticker,
        name: name,
        type: type,
        sector: item['sector'] as String?,
        price: (item['price'] as num?)?.toDouble(),
        dayChange: (item['dayChange'] as num?)?.toDouble(),
        dayChangePercent: (item['dayChangePercent'] as num?)?.toDouble(),
        currency: item['currency'] as String? ?? 'RUB',
      ));
    }
    return result;
  }

  static List<Map<String, dynamic>> _encodeCatalog(
      List<InvestmentInstrument> items) {
    return items
        .map((i) => {
              'ticker': i.ticker,
              'name': i.name,
              'type': i.type,
              'sector': i.sector,
              'price': i.price,
              'dayChange': i.dayChange,
              'dayChangePercent': i.dayChangePercent,
              'currency': i.currency,
            })
        .toList();
  }

  /// Получение списка популярных инвестиционных инструментов с MOEX.
  ///
  /// Стратегия:
  /// 1. Пытаемся сходить в MOEX; при успехе — обновляем Hive-кеш.
  /// 2. Если MOEX недоступен (таймаут/ошибка) — возвращаем последнее
  ///    закешированное значение из Hive.
  /// 3. Если кеша тоже нет — возвращаем встроенный fallback-список.
  static Future<List<InvestmentInstrument>> getPopularInstruments() async {
    final List<InvestmentInstrument> instruments = [];

    try {
      // Получаем данные по акциям
      const url = '$_moexBaseUrl/engines/stock/markets/shares/boards/TQBR/securities.json';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Получаем список бумаг
        final securities = data['securities'];
        if (securities != null && securities['data'] != null) {
          final columns = securities['columns'];
          final rows = securities['data'];

          for (var row in rows) {
            final instrument = _parseMoexInstrument(columns, row);
            if (instrument != null) {
              instruments.add(instrument);
            }
          }
        }

        // Теперь получаем marketdata для цен
        const marketdataUrl = '$_moexBaseUrl/engines/stock/markets/shares/boards/TQBR/securities.json?marketdata=marketdata';
        final marketResponse = await http.get(Uri.parse(marketdataUrl)).timeout(
          const Duration(seconds: 10),
        );

        if (marketResponse.statusCode == 200) {
          final marketData = json.decode(marketResponse.body);
          final md = marketData['marketdata'];
          
          if (md != null && md['data'] != null) {
            final mdColumns = md['columns'];
            final mdRows = md['data'];

            // Обновляем цены в инструментах
            for (var mdRow in mdRows) {
              final secidIndex = mdColumns.indexOf('SECID');
              final lastIndex = mdColumns.indexOf('LAST');
              final changeIndex = mdColumns.indexOf('CHANGE');
              final lastToPrevPriceIndex = mdColumns.indexOf('LASTTOPREVPRICE');

              if (secidIndex != -1) {
                final ticker = mdRow[secidIndex];
                final price = lastIndex != -1 && mdRow[lastIndex] != null 
                    ? (mdRow[lastIndex] as num).toDouble() 
                    : null;
                final change = changeIndex != -1 && mdRow[changeIndex] != null
                    ? (mdRow[changeIndex] as num).toDouble()
                    : null;
                final changePercent = lastToPrevPriceIndex != -1 && mdRow[lastToPrevPriceIndex] != null
                    ? (mdRow[lastToPrevPriceIndex] as num).toDouble()
                    : null;

                // Обновляем соответствующий инструмент
                final index = instruments.indexWhere((i) => i.ticker == ticker);
                if (index != -1) {
                  instruments[index] = InvestmentInstrument(
                    ticker: instruments[index].ticker,
                    name: instruments[index].name,
                    type: instruments[index].type,
                    sector: instruments[index].sector,
                    price: price,
                    dayChange: change,
                    dayChangePercent: changePercent,
                    currency: 'RUB',
                  );
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Ошибка получения популярных инструментов MOEX: $e');
    }

    if (instruments.isNotEmpty) {
      // Сохраняем успешный ответ в Hive — пригодится в офлайне.
      try {
        final box = await _openCatalogBox();
        await box?.put(_catalogKey, _encodeCatalog(instruments));
      } catch (e) {
        debugPrint('Не удалось сохранить кеш каталога: $e');
      }
      return instruments;
    }

    // MOEX недоступен — пробуем последний закешированный каталог.
    final box = await _openCatalogBox();
    final cached = _decodeCachedCatalog(box?.get(_catalogKey));
    if (cached.isNotEmpty) return cached;

    return _getDefaultInstruments();
  }

  /// Поиск инструментов по тикеру или названию
  static Future<List<InvestmentInstrument>> searchInstruments(String query) async {
    if (query.isEmpty) {
      return getPopularInstruments();
    }

    final List<InvestmentInstrument> results = [];
    query = query.toUpperCase();

    try {
      // Поиск через MOEX API
      final url = '$_moexBaseUrl/securities.json?q=$query';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final securities = data['securities'];
        
        if (securities != null && securities['data'] != null) {
          final columns = securities['columns'];
          final rows = securities['data'];

          for (var row in rows) {
            final secidIndex = columns.indexOf('SECID');
            final nameIndex = columns.indexOf('NAME');
            final _ = columns.indexOf('ISIN');

            if (secidIndex != -1) {
              final ticker = row[secidIndex];
              final name = nameIndex != -1 ? row[nameIndex] : ticker;
              
              if (ticker.toString().toUpperCase().contains(query) ||
                  name.toString().toUpperCase().contains(query)) {
                results.add(InvestmentInstrument(
                  ticker: ticker,
                  name: name,
                  type: _detectInstrumentType(ticker),
                  currency: 'RUB',
                ));
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Ошибка поиска инструментов: $e');
    }

    // Если ничего не найдено, ищем в локальном списке
    if (results.isEmpty) {
      final allInstruments = _getDefaultInstruments();
      for (var instrument in allInstruments) {
        if (instrument.ticker.toUpperCase().contains(query) ||
            instrument.name.toUpperCase().contains(query)) {
          results.add(instrument);
        }
      }
    }

    return results;
  }

  /// Одним HTTP-запросом тянет marketdata для всей доски TQBR и
  /// возвращает map тикер → последняя цена. Этот эндпоинт ощутимо
  /// быстрее и стабильнее, чем точечные `getMoexPrice` по каждому
  /// тикеру (которые любят таймаутить на медленной сети).
  static Future<Map<String, double>> getMoexBoardPrices({
    String board = 'TQBR',
  }) async {
    try {
      final url =
          '$_moexBaseUrl/engines/stock/markets/shares/boards/$board/securities.json?marketdata=marketdata';
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return const {};
      final data = json.decode(resp.body);
      final md = data['marketdata'];
      if (md is! Map ||
          md['columns'] is! List ||
          md['data'] is! List) {
        return const {};
      }
      final cols = (md['columns'] as List).cast<String>();
      final secidIdx = cols.indexOf('SECID');
      final lastIdx = cols.indexOf('LAST');
      if (secidIdx == -1 || lastIdx == -1) return const {};
      final out = <String, double>{};
      for (final row in (md['data'] as List)) {
        if (row is! List) continue;
        final ticker = row[secidIdx];
        final price = row[lastIdx];
        if (ticker is String && price is num && price > 0) {
          out[ticker.toUpperCase()] = price.toDouble();
        }
      }
      return out;
    } catch (e) {
      debugPrint('Ошибка batch-загрузки цен MOEX: $e');
      return const {};
    }
  }

  /// Возвращает массив цен закрытия за последние [days] торговых дней.
  /// Используется для рисования sparkline-графика в каталоге/карточке актива.
  /// При ошибке вернёт пустой список — UI покажет заглушку.
  static Future<List<double>> getCandles(String ticker, {int days = 30}) async {
    try {
      final from = DateTime.now().subtract(Duration(days: days * 2));
      final fromStr =
          '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
      final url =
          '$_moexBaseUrl/engines/stock/markets/shares/securities/$ticker/candles.json'
          '?from=$fromStr&interval=24';
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return const [];
      final data = json.decode(resp.body);
      final candles = data['candles'];
      if (candles is! Map ||
          candles['columns'] is! List ||
          candles['data'] is! List) {
        return const [];
      }
      final cols = (candles['columns'] as List).cast<String>();
      final closeIdx = cols.indexOf('close');
      if (closeIdx == -1) return const [];
      final rows = candles['data'] as List;
      final closes = <double>[];
      for (final row in rows) {
        if (row is List && row.length > closeIdx && row[closeIdx] is num) {
          closes.add((row[closeIdx] as num).toDouble());
        }
      }
      if (closes.length <= days) return closes;
      return closes.sublist(closes.length - days);
    } catch (e) {
      debugPrint('Ошибка получения свечей для $ticker: $e');
      return const [];
    }
  }

  /// Получение детальной информации об инструменте
  static Future<InvestmentInstrument?> getInstrumentDetails(String ticker) async {
    try {
      // Получаем цену
      final price = await getMoexPrice(ticker);
      
      if (price != null) {
        return InvestmentInstrument(
          ticker: ticker,
          name: ticker,
          type: _detectInstrumentType(ticker),
          price: price,
          currency: 'RUB',
        );
      }
    } catch (e) {
      debugPrint('Ошибка получения деталей $ticker: $e');
    }
    return null;
  }

  /// Парсинг инструмента из данных MOEX
  static InvestmentInstrument? _parseMoexInstrument(List columns, List row) {
    try {
      final secidIndex = columns.indexOf('SECID');
      final nameIndex = columns.indexOf('NAME');
      final shortnameIndex = columns.indexOf('SHORTNAME');

      if (secidIndex != -1) {
        final ticker = row[secidIndex];
        final name = nameIndex != -1 && row[nameIndex] != null 
            ? row[nameIndex] 
            : shortnameIndex != -1 && row[shortnameIndex] != null
                ? row[shortnameIndex]
                : ticker;

        return InvestmentInstrument(
          ticker: ticker,
          name: name,
          type: _detectInstrumentType(ticker),
          currency: 'RUB',
        );
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Определение типа инструмента по тикеру
  static String _detectInstrumentType(String ticker) {
    ticker = ticker.toUpperCase();
    
    // Облигации обычно содержат буквы в конце для обозначения выпуска
    if (ticker.contains('-') || RegExp(r'\d{2}[A-Z]').hasMatch(ticker)) {
      return 'bond';
    }
    
    // ETF и фонды
    if (ticker.startsWith('TMOS') || 
        ticker.startsWith('SBMX') || 
        ticker.startsWith('LQDT') ||
        ticker.startsWith('VTBR') && ticker.contains('ETF')) {
      return 'etf';
    }

    return 'stock';
  }

  /// Дефолтный список популярных инструментов
  static List<InvestmentInstrument> _getDefaultInstruments() {
    return [
      // Голубые фишки
      InvestmentInstrument(ticker: 'SBER', name: 'Сбербанк', type: 'stock', sector: 'Финансы'),
      InvestmentInstrument(ticker: 'GAZP', name: 'Газпром', type: 'stock', sector: 'Энергетика'),
      InvestmentInstrument(ticker: 'LKOH', name: 'ЛУКОЙЛ', type: 'stock', sector: 'Энергетика'),
      InvestmentInstrument(ticker: 'YNDX', name: 'Яндекс', type: 'stock', sector: 'Технологии'),
      InvestmentInstrument(ticker: 'GMKN', name: 'Норникель', type: 'stock', sector: 'Металлургия'),
      InvestmentInstrument(ticker: 'NVTK', name: 'Новатэк', type: 'stock', sector: 'Энергетика'),
      InvestmentInstrument(ticker: 'ROSN', name: 'Роснефть', type: 'stock', sector: 'Энергетика'),
      InvestmentInstrument(ticker: 'VTBR', name: 'ВТБ', type: 'stock', sector: 'Финансы'),
      InvestmentInstrument(ticker: 'MGNT', name: 'Магнит', type: 'stock', sector: 'Потребительский'),
      InvestmentInstrument(ticker: 'AFLT', name: 'Аэрофлот', type: 'stock', sector: 'Транспорт'),
      
      // IT и технологии
      InvestmentInstrument(ticker: 'OZON', name: 'Ozon', type: 'stock', sector: 'Технологии'),
      InvestmentInstrument(ticker: 'VKCO', name: 'VK', type: 'stock', sector: 'Технологии'),
      InvestmentInstrument(ticker: 'TCSG', name: 'ТКС Холдинг', type: 'stock', sector: 'Финансы'),
      InvestmentInstrument(ticker: 'MTSS', name: 'МТС', type: 'stock', sector: 'Телеком'),
      
      // Металлургия
      InvestmentInstrument(ticker: 'ALRS', name: 'Алроса', type: 'stock', sector: 'Металлургия'),
      InvestmentInstrument(ticker: 'NLMK', name: 'НЛМК', type: 'stock', sector: 'Металлургия'),
      InvestmentInstrument(ticker: 'CHMF', name: 'Северсталь', type: 'stock', sector: 'Металлургия'),
      InvestmentInstrument(ticker: 'MAGN', name: 'ММК', type: 'stock', sector: 'Металлургия'),
      
      // Потребительский сектор
      InvestmentInstrument(ticker: 'X5GR', name: 'X5 Group', type: 'stock', sector: 'Потребительский'),
      InvestmentInstrument(ticker: 'MGTS', name: 'МТС', type: 'stock', sector: 'Телеком'),
      
      // ETF и фонды
      InvestmentInstrument(ticker: 'TMOS', name: 'Т-Технологии', type: 'etf'),
      InvestmentInstrument(ticker: 'SBMX', name: 'Сбер - Индекс МосБиржи', type: 'etf'),
      InvestmentInstrument(ticker: 'LQDT', name: 'Ликвидность', type: 'etf'),
    ];
  }
}
