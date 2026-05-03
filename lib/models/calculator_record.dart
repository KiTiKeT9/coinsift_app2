import 'package:hive/hive.dart';

part 'calculator_record.g.dart';

@HiveType(typeId: 4)
class CalculatorRecord extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String type; // 'mortgage', 'loan', 'deposit'

  @HiveField(2)
  String bankName;

  @HiveField(3)
  double amount;

  @HiveField(4)
  double interestRate;

  @HiveField(5)
  int termMonths;

  @HiveField(6)
  DateTime calculationDate;

  @HiveField(7)
  double monthlyPayment;

  @HiveField(8)
  double totalPayment;

  @HiveField(9)
  double totalInterest;

  @HiveField(10)
  Map<String, dynamic>? additionalData;

  CalculatorRecord({
    required this.id,
    required this.type,
    required this.bankName,
    required this.amount,
    required this.interestRate,
    required this.termMonths,
    required this.calculationDate,
    required this.monthlyPayment,
    required this.totalPayment,
    required this.totalInterest,
    this.additionalData,
  });
}
