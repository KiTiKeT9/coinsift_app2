import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/transaction_deduplicator.dart';

class TransactionsProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final _uuid = const Uuid();
  final _deduplicator = TransactionDeduplicator();

  List<Transaction> _transactions = [];
  bool _isLoading = false;

  /// Все транзакции, включая черновики из SMS/push.
  List<Transaction> get transactions => _transactions;

  /// Только подтверждённые транзакции — учитываются в балансе и аналитике.
  List<Transaction> get confirmed =>
      _transactions.where((t) => !t.isDraft).toList();

  /// Черновики из SMS/push, ожидающие подтверждения пользователем.
  List<Transaction> get drafts =>
      _transactions.where((t) => t.isDraft).toList();

  bool get isLoading => _isLoading;

  double get totalIncome {
    return confirmed
        .where((t) => t.type == 'income')
        .fold(0, (sum, t) => sum + t.amount);
  }

  double get totalExpenses {
    return confirmed
        .where((t) => t.type == 'expense')
        .fold(0, (sum, t) => sum + t.amount);
  }

  double get balance => totalIncome - totalExpenses;

  Map<String, double> get expensesByCategory {
    final Map<String, double> categoryMap = {};
    for (var transaction in confirmed.where((t) => t.type == 'expense')) {
      categoryMap[transaction.category] =
          (categoryMap[transaction.category] ?? 0) + transaction.amount;
    }
    return categoryMap;
  }

  Map<String, double> get incomeByCategory {
    final Map<String, double> categoryMap = {};
    for (var transaction in confirmed.where((t) => t.type == 'income')) {
      categoryMap[transaction.category] =
          (categoryMap[transaction.category] ?? 0) + transaction.amount;
    }
    return categoryMap;
  }

  List<Transaction> getTransactionsByAccount(String accountId) {
    return confirmed.where((t) => t.accountId == accountId).toList();
  }

  List<Transaction> getTransactionsByDateRange(DateTime start, DateTime end) {
    return confirmed
        .where((t) => t.date.isAfter(start.subtract(const Duration(days: 1))) &&
            t.date.isBefore(end.add(const Duration(days: 1))))
        .toList();
  }

  List<Transaction> getRecentTransactions({int limit = 10}) {
    final sorted = List<Transaction>.from(confirmed)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(limit).toList();
  }

  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    _transactions = _db.allTransactions;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTransaction({
    required String accountId,
    required double amount,
    required String type,
    required String category,
    String description = '',
    String currency = 'RUB',
    String? merchantName,
    List<String> tags = const [], DateTime? date,
  }) async {
    final transaction = Transaction(
      id: _uuid.v4(),
      accountId: accountId,
      amount: amount,
      type: type,
      category: category,
      description: description,
      date: DateTime.now(),
      currency: currency,
      merchantName: merchantName,
      tags: tags,
    );

    await _db.addTransaction(transaction);

    // Update account balance
    final account = _db.getAccount(accountId);
    if (account != null) {
      if (type == 'income') {
        account.balance += amount;
      } else if (type == 'expense') {
        account.balance -= amount;
      }
      await _db.updateAccount(account);
    }

    await loadTransactions();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await _db.updateTransaction(transaction);
    await loadTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    final transaction = _db.transactionsBox.get(id);
    if (transaction != null) {
      // Reverse the balance change
      final account = _db.getAccount(transaction.accountId);
      if (account != null) {
        if (transaction.type == 'income') {
          account.balance -= transaction.amount;
        } else if (transaction.type == 'expense') {
          account.balance += transaction.amount;
        }
        await _db.updateAccount(account);
      }

      await _db.deleteTransaction(id);
      await loadTransactions();
    }
  }

  /// Массовый импорт транзакций (выписки, SMS, push) с дедупликацией.
  ///
  /// Логика для каждой входящей транзакции:
  ///  * Если в БД уже есть запись с тем же fingerprint или fuzzy-match —
  ///    дублем считается и пропускается. При этом, если входящая запись
  ///    более авторитетная (например, импорт против push-черновика),
  ///    данные сливаются в существующую и черновик подтверждается.
  ///  * Иначе создаётся новая запись + обновляется баланс счёта,
  ///    но **только если это не черновик** (черновики не двигают баланс).
  ///
  /// Возвращает статистику: сколько добавлено / сколько подтверждено
  /// существующих черновиков / сколько отброшено как дубли.
  Future<BulkImportStats> bulkImport(Iterable<Transaction> incoming) async {
    int added = 0;
    int merged = 0;
    int skipped = 0;

    for (final raw in incoming) {
      // Гарантируем, что у входящей всегда есть id и externalId.
      if (raw.id.isEmpty) raw.id = _uuid.v4();
      raw.externalId ??= TransactionDeduplicator.fingerprintOf(raw);

      final dup = _deduplicator.findDuplicate(raw, _transactions);
      if (dup != null) {
        // Если существующая была черновиком, а новая авторитетнее —
        // подтверждаем существующую и обновляем баланс.
        final wasDraft = dup.isDraft;
        _deduplicator.mergeInto(dup, raw);
        await _db.updateTransaction(dup);

        if (wasDraft && !dup.isDraft) {
          await _applyToAccountBalance(dup, sign: 1);
          merged++;
        } else {
          skipped++;
        }
        continue;
      }

      await _db.addTransaction(raw);
      if (!raw.isDraft) {
        await _applyToAccountBalance(raw, sign: 1);
      }
      added++;
    }

    await loadTransactions();
    return BulkImportStats(added: added, merged: merged, skipped: skipped);
  }

  /// Подтвердить черновик из SMS/push: снимает флаг `isDraft` и
  /// применяет операцию к балансу счёта.
  Future<void> confirmDraft(Transaction draft, {String? accountId}) async {
    if (!draft.isDraft) return;
    draft.isDraft = false;
    if (accountId != null) draft.accountId = accountId;
    await _db.updateTransaction(draft);
    await _applyToAccountBalance(draft, sign: 1);
    await loadTransactions();
  }

  /// Отклонить черновик: удаляет запись без влияния на баланс.
  Future<void> rejectDraft(String id) async {
    final t = _db.transactionsBox.get(id);
    if (t == null) return;
    if (!t.isDraft) return; // безопасность: не удаляем подтверждённое
    await _db.deleteTransaction(id);
    await loadTransactions();
  }

  Future<void> _applyToAccountBalance(Transaction t, {required int sign}) async {
    final account = _db.getAccount(t.accountId);
    if (account == null) return;
    final delta = sign * (t.type == 'income' ? t.amount : -t.amount);
    account.balance += delta;
    await _db.updateAccount(account);
  }

  Map<String, double> getMonthlyStats(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final monthTransactions = getTransactionsByDateRange(start, end);

    return {
      'income': monthTransactions
          .where((t) => t.type == 'income')
          .fold(0, (sum, t) => sum + t.amount),
      'expenses': monthTransactions
          .where((t) => t.type == 'expense')
          .fold(0, (sum, t) => sum + t.amount),
    };
  }
}

/// Статистика массового импорта.
class BulkImportStats {
  const BulkImportStats({
    required this.added,
    required this.merged,
    required this.skipped,
  });

  /// Сколько новых транзакций было добавлено.
  final int added;

  /// Сколько уже существующих черновиков было подтверждено через слияние.
  final int merged;

  /// Сколько входящих было отброшено как дубли существующих.
  final int skipped;

  int get total => added + merged + skipped;
}
