import 'package:hive/hive.dart';

part 'transaction.g.dart';

/// Источник транзакции — критичен для дедупликации между импортом и
/// автоматическими источниками (SMS / push).
///
/// Значения хранятся как строки для совместимости со старыми Hive-боксами
/// (старые транзакции читаются как `manual`).
class TransactionSource {
  /// Введена пользователем вручную через UI.
  static const String manual = 'manual';

  /// Импортирована из выписки (CSV/PDF/Excel/OFX).
  static const String statementImport = 'statement_import';

  /// Распознана из входящего SMS банка.
  static const String sms = 'sms';

  /// Распознана из push-уведомления банковского приложения.
  static const String push = 'push';

  /// Получена из API партнёрского банка / агрегатора.
  static const String api = 'api';

  static const Set<String> all = {manual, statementImport, sms, push, api};
}

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

  /// Откуда пришла транзакция (см. [TransactionSource]).
  /// `null` для старых записей до миграции — трактуется как `manual`.
  @HiveField(12)
  String? source;

  /// Стабильный отпечаток транзакции для дедупликации между источниками.
  /// Формируется как SHA-1 от `(date_minute + amount_cents + sign + bankId + merchant)`.
  /// Подробнее: `TransactionFingerprint.compute`.
  @HiveField(13)
  String? externalId;

  /// Идентификатор банка-источника (например `tinkoff`, `sber`, `alfa`).
  /// Используется и для подгрузки логотипов, и для скоупинга fingerprint.
  @HiveField(14)
  String? bankId;

  /// `true`, если это черновик из SMS/push, ещё не подтверждённый пользователем.
  /// Черновики **не учитываются** в балансе и аналитике до подтверждения.
  @HiveField(15)
  bool isDraft;

  /// Маска последних 4 цифр карты, если удалось извлечь из сообщения банка.
  @HiveField(16)
  String? cardMask;

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
    this.source,
    this.externalId,
    this.bankId,
    this.isDraft = false,
    this.cardMask,
  });

  /// Удобный геттер: фактический источник с учётом дефолта.
  String get effectiveSource => source ?? TransactionSource.manual;
}
