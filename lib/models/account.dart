import 'package:hive/hive.dart';

part 'account.g.dart';

@HiveType(typeId: 0)
class Account extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double balance;

  @HiveField(3)
  String currency;

  @HiveField(4)
  String bankName;

  @HiveField(5)
  String accountType; // 'debit', 'credit', 'cash', 'investment'

  @HiveField(6)
  String? cardNumber;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  String color;

  @HiveField(9)
  bool isArchived;

  Account({
    required this.id,
    required this.name,
    required this.balance,
    this.currency = 'RUB',
    this.bankName = '',
    this.accountType = 'debit',
    this.cardNumber,
    required this.createdAt,
    this.color = '#4CAF50',
    this.isArchived = false,
  });
}
