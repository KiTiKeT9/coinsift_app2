
class InvestmentInstrument {
  final String ticker;
  final String name;
  final String type; // 'stock', 'bond', 'etf', 'fund', 'currency'
  final String? sector;
  final String? exchange;
  final double? price;
  final double? dayChange;
  final double? dayChangePercent;
  final String? currency;
  final String? description;
  final double? marketCap;
  final double? volume;
  final double? high52Week;
  final double? low52Week;
  final double? dividendYield;

  InvestmentInstrument({
    required this.ticker,
    required this.name,
    required this.type,
    this.sector,
    this.exchange,
    this.price,
    this.dayChange,
    this.dayChangePercent,
    this.currency = 'RUB',
    this.description,
    this.marketCap,
    this.volume,
    this.high52Week,
    this.low52Week,
    this.dividendYield,
  });

  bool get isPositive => (dayChangePercent ?? 0) >= 0;

  String get typeLabel {
    switch (type) {
      case 'stock':
        return 'Акция';
      case 'bond':
        return 'Облигация';
      case 'etf':
        return 'ETF';
      case 'fund':
        return 'ПИФ';
      case 'currency':
        return 'Валюта';
      default:
        return type;
    }
  }

  String get typeEmoji {
    switch (type) {
      case 'stock':
        return '📈';
      case 'bond':
        return '📜';
      case 'etf':
        return '💼';
      case 'fund':
        return '🏦';
      case 'currency':
        return '💱';
      default:
        return '📊';
    }
  }
}
