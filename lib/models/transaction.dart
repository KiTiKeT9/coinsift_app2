import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 1)
class Transaction extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String accountId;

  @HiveField(2)
  double amount;

  @HiveField(3)
  String type; // 'income', 'expense', 'transfer'

  @HiveField(4)
  String category;

  @HiveField(5)
  String description;

  @HiveField(6)
  DateTime date;

  @HiveField(7)
  String currency;

  @HiveField(8)
  String? merchantName;

  @HiveField(9)
  List<String> tags;

  @HiveField(10)
  bool isRecurring;

  @HiveField(11)
  String? recurringPeriod; // 'daily', 'weekly', 'monthly', 'yearly'

  Transaction({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.type,
    required this.category,
    this.description = '',
    required this.date,
    this.currency = 'RUB',
    this.merchantName,
    this.tags = const [],
    this.isRecurring = false,
    this.recurringPeriod,
  });
}
