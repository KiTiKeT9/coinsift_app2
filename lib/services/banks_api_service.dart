class BankRate {
  final String bankName;
  final String shortName;
  final double mortgageRate;
  final double loanRate;
  final double depositRate;
  final String color;
  final String logo;

  BankRate({
    required this.bankName,
    required this.shortName,
    required this.mortgageRate,
    required this.loanRate,
    required this.depositRate,
    required this.color,
    required this.logo,
  });

  factory BankRate.fromJson(Map<String, dynamic> json) {
    return BankRate(
      bankName: json['name'] ?? '',
      shortName: json['short_name'] ?? '',
      mortgageRate: (json['mortgage_rate'] ?? 0).toDouble(),
      loanRate: (json['loan_rate'] ?? 0).toDouble(),
      depositRate: (json['deposit_rate'] ?? 0).toDouble(),
      color: json['color'] ?? '#21A038',
      logo: json['logo'] ?? 'sber',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': bankName,
      'short_name': shortName,
      'mortgage_rate': mortgageRate,
      'loan_rate': loanRate,
      'deposit_rate': depositRate,
      'color': color,
      'logo': logo,
    };
  }
}

class BanksApiService {
  static final BanksApiService _instance = BanksApiService._internal();
  factory BanksApiService() => _instance;
  BanksApiService._internal();

  // Кэш для хранения данных
  List<BankRate> _cachedRates = [];
  DateTime? _lastUpdate;
  static const _cacheDuration = Duration(hours: 6);

  // Резервные данные (если API недоступен)
  final List<BankRate> _fallbackRates = [
    BankRate(
      bankName: 'СберБанк',
      shortName: 'Сбер',
      mortgageRate: 17.5,
      loanRate: 18.5,
      depositRate: 16.0,
      color: '#21A038',
      logo: 'sber',
    ),
    BankRate(
      bankName: 'Тинькофф Банк',
      shortName: 'Тинькофф',
      mortgageRate: 17.0,
      loanRate: 19.0,
      depositRate: 15.5,
      color: '#FFDD2D',
      logo: 'tinkoff',
    ),
    BankRate(
      bankName: 'Альфа-Банк',
      shortName: 'Альфа',
      mortgageRate: 17.3,
      loanRate: 18.0,
      depositRate: 16.5,
      color: '#EF3124',
      logo: 'alfa',
    ),
    BankRate(
      bankName: 'ВТБ',
      shortName: 'ВТБ',
      mortgageRate: 17.8,
      loanRate: 19.5,
      depositRate: 15.8,
      color: '#002882',
      logo: 'vtb',
    ),
    BankRate(
      bankName: 'Газпромбанк',
      shortName: 'ГПБ',
      mortgageRate: 17.6,
      loanRate: 18.8,
      depositRate: 15.7,
      color: '#0055A5',
      logo: 'gpb',
    ),
    BankRate(
      bankName: 'Райффайзен Банк',
      shortName: 'Райффайзен',
      mortgageRate: 17.9,
      loanRate: 19.2,
      depositRate: 15.3,
      color: '#E30613',
      logo: 'raiffeisen',
    ),
    BankRate(
      bankName: 'Открытие',
      shortName: 'Открытие',
      mortgageRate: 17.7,
      loanRate: 19.3,
      depositRate: 15.9,
      color: '#00174E',
      logo: 'otkritie',
    ),
    BankRate(
      bankName: 'Росбанк',
      shortName: 'Росбанк',
      mortgageRate: 17.4,
      loanRate: 18.9,
      depositRate: 15.6,
      color: '#FF6200',
      logo: 'rosbank',
    ),
  ];

  /// Получить актуальные ставки банков
  Future<List<BankRate>> getBankRates({bool forceRefresh = false}) async {
    // Проверяем кэш
    if (!forceRefresh &&
        _cachedRates.isNotEmpty &&
        _lastUpdate != null &&
        DateTime.now().difference(_lastUpdate!) < _cacheDuration) {
      return _cachedRates;
    }

    try {
      // Пытаемся загрузить с API (симуляция - в реальном проекте заменить на настоящий API)
      // Для демонстрации используем fallback данные с небольшой рандомизацией
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Симуляция обновления ставок (в реальном проекте здесь будет HTTP запрос)
      _cachedRates = _fallbackRates.map((bank) {
        final randomChange = (DateTime.now().millisecond % 5 - 2) / 10;
        return BankRate(
          bankName: bank.bankName,
          shortName: bank.shortName,
          mortgageRate: bank.mortgageRate + randomChange,
          loanRate: bank.loanRate + randomChange,
          depositRate: bank.depositRate + randomChange,
          color: bank.color,
          logo: bank.logo,
        );
      }).toList();
      
      _lastUpdate = DateTime.now();
      return _cachedRates;
    } catch (e) {
      // При ошибке возвращаем резервные данные
      _cachedRates = _fallbackRates;
      _lastUpdate = DateTime.now();
      return _cachedRates;
    }
  }

  /// Получить лучшую ставку по типу продукта
  BankRate? getBestRate(String productType) {
    if (_cachedRates.isEmpty) return null;

    switch (productType.toLowerCase()) {
      case 'mortgage':
        return _cachedRates.reduce((a, b) => 
          a.mortgageRate < b.mortgageRate ? a : b);
      case 'loan':
        return _cachedRates.reduce((a, b) => 
          a.loanRate < b.loanRate ? a : b);
      case 'deposit':
        return _cachedRates.reduce((a, b) => 
          a.depositRate > b.depositRate ? a : b);
      default:
        return null;
    }
  }

  /// Сравнить все банки по продукту
  List<Map<String, dynamic>> compareBanks(String productType) {
    final comparisons = <Map<String, dynamic>>[];
    
    for (final bank in _cachedRates) {
      double rate = 0;
      switch (productType.toLowerCase()) {
        case 'mortgage':
          rate = bank.mortgageRate;
          break;
        case 'loan':
          rate = bank.loanRate;
          break;
        case 'deposit':
          rate = bank.depositRate;
          break;
      }
      
      comparisons.add({
        'bank': bank,
        'rate': rate,
        'isBest': productType == 'deposit' 
            ? rate == _cachedRates.map((b) => b.depositRate).reduce((a, b) => a > b ? a : b)
            : rate == _cachedRates.map((b) => productType == 'mortgage' ? b.mortgageRate : b.loanRate).reduce((a, b) => a < b ? a : b),
      });
    }
    
    // Сортируем: для вкладов - по убыванию, для кредитов - по возрастанию
    comparisons.sort((a, b) {
      final rateA = a['rate'] as double;
      final rateB = b['rate'] as double;
      return productType == 'deposit' 
          ? rateB.compareTo(rateA) 
          : rateA.compareTo(rateB);
    });
    
    return comparisons;
  }

  DateTime? get lastUpdate => _lastUpdate;
  bool get isDataLoaded => _cachedRates.isNotEmpty;
  List<BankRate> get cachedRates => _cachedRates;
}
