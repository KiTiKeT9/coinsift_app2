import 'package:hive/hive.dart';

part 'investment.g.dart';

@HiveType(typeId: 3)
class Investment extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String ticker;

  @HiveField(3)
  String type; // 'stock', 'bond', 'etf', 'fund'

  @HiveField(4)
  int quantity;

  @HiveField(5)
  double averagePrice;

  @HiveField(6)
  double currentPrice;

  @HiveField(7)
  String currency;

  @HiveField(8)
  DateTime purchaseDate;

  @HiveField(9)
  String? exchange;

  @HiveField(10)
  String sector;

  Investment({
    required this.id,
    required this.name,
    required this.ticker,
    required this.type,
    required this.quantity,
    required this.averagePrice,
    required this.currentPrice,
    this.currency = 'RUB',
    required this.purchaseDate,
    this.exchange,
    this.sector = '',
  });

  double get totalValue => quantity * currentPrice;
  double get totalCost => quantity * averagePrice;
  double get profitLoss => totalValue - totalCost;
  double get profitLossPercent => totalCost != 0 ? (profitLoss / totalCost) * 100 : 0;
}
