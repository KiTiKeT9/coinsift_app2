import 'package:hive/hive.dart';

part 'currency_rate.g.dart';

@HiveType(typeId: 5)
class CurrencyRate extends HiveObject {
  @HiveField(0)
  String currency;

  @HiveField(1)
  double rate;

  @HiveField(2)
  String baseCurrency;

  @HiveField(3)
  DateTime lastUpdated;

  CurrencyRate({
    required this.currency,
    required this.rate,
    required this.baseCurrency,
    required this.lastUpdated,
  });
}
