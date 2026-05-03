import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

class TransactionsProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final _uuid = const Uuid();

  List<Transaction> _transactions = [];
  bool _isLoading = false;

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;

  double get totalIncome {
    return _transactions
        .where((t) => t.type == 'income')
        .fold(0, (sum, t) => sum + t.amount);
  }

  double get totalExpenses {
    return _transactions
        .where((t) => t.type == 'expense')
        .fold(0, (sum, t) => sum + t.amount);
  }

  double get balance => totalIncome - totalExpenses;

  Map<String, double> get expensesByCategory {
    final Map<String, double> categoryMap = {};
    for (var transaction in _transactions.where((t) => t.type == 'expense')) {
      categoryMap[transaction.category] =
          (categoryMap[transaction.category] ?? 0) + transaction.amount;
    }
    return categoryMap;
  }

  Map<String, double> get incomeByCategory {
    final Map<String, double> categoryMap = {};
    for (var transaction in _transactions.where((t) => t.type == 'income')) {
      categoryMap[transaction.category] =
          (categoryMap[transaction.category] ?? 0) + transaction.amount;
    }
    return categoryMap;
  }

  List<Transaction> getTransactionsByAccount(String accountId) {
    return _transactions.where((t) => t.accountId == accountId).toList();
  }

  List<Transaction> getTransactionsByDateRange(DateTime start, DateTime end) {
    return _transactions
        .where((t) => t.date.isAfter(start.subtract(const Duration(days: 1))) &&
            t.date.isBefore(end.add(const Duration(days: 1))))
        .toList();
  }

  List<Transaction> getRecentTransactions({int limit = 10}) {
    final sorted = List<Transaction>.from(_transactions)
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
