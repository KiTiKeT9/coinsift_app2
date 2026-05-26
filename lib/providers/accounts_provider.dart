import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/account.dart';
import '../models/currency_rate.dart';
import '../services/database_service.dart';
import '../services/currency_service.dart';

class AccountsProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final _uuid = const Uuid();
  final _currencyService = CurrencyService();

  List<Account> _accounts = [];
  bool _isLoading = false;

  List<Account> get accounts => _accounts;
  bool get isLoading => _isLoading;

  double get totalBalance {
    return _accounts.where((a) => !a.isArchived).fold(
      0,
      (sum, account) => sum + account.balance,
    );
  }

  double getConvertedBalance(String toCurrency) {
    final cached = _currencyService.cachedRates;
    if (cached == null || cached.isEmpty) return totalBalance;
    return _accounts.where((a) => !a.isArchived).fold(
      0,
      (sum, account) => sum + _convert(account.balance, account.currency, toCurrency, cached),
    );
  }

  double _convert(double amount, String from, String to, List<CurrencyRate> rates) {
    if (from == to) return amount;
    if (to == 'USD') {
      final rate = rates.where((r) => r.currency == from).firstOrNull;
      return rate != null ? amount / rate.rate : amount;
    }
    if (from == 'USD') {
      final rate = rates.where((r) => r.currency == to).firstOrNull;
      return rate != null ? amount * rate.rate : amount;
    }
    final fromRate = rates.where((r) => r.currency == from).firstOrNull;
    final toRate = rates.where((r) => r.currency == to).firstOrNull;
    if (fromRate == null || toRate == null) return amount;
    return amount / fromRate.rate * toRate.rate;
  }

  List<Account> get activeAccounts =>
      _accounts.where((a) => !a.isArchived).toList();

  List<Account> get archivedAccounts =>
      _accounts.where((a) => a.isArchived).toList();

  Future<void> loadAccounts() async {
    _isLoading = true;
    notifyListeners();

    _accounts = _db.allAccounts;
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addAccount({
    required String name,
    required double balance,
    String currency = 'RUB',
    String bankName = '',
    String accountType = 'debit',
    String? cardNumber,
    String color = '#4CAF50',
  }) async {
    final account = Account(
      id: _uuid.v4(),
      name: name,
      balance: balance,
      currency: currency,
      bankName: bankName,
      accountType: accountType,
      cardNumber: cardNumber,
      createdAt: DateTime.now(),
      color: color,
    );

    await _db.addAccount(account);
    await loadAccounts();
  }

  Future<void> updateAccount(Account account) async {
    await _db.updateAccount(account);
    await loadAccounts();
  }

  Future<void> updateBalance(String id, double newBalance) async {
    final account = _db.getAccount(id);
    if (account != null) {
      account.balance = newBalance;
      await _db.updateAccount(account);
      await loadAccounts();
    }
  }

  Future<void> deleteAccount(String id) async {
    await _db.deleteAccount(id);
    await loadAccounts();
  }

  Future<void> archiveAccount(String id) async {
    final account = _db.getAccount(id);
    if (account != null) {
      account.isArchived = true;
      await _db.updateAccount(account);
      await loadAccounts();
    }
  }

  Account? getAccountById(String id) {
    final matches = _accounts.where((a) => a.id == id).toList();
    return matches.isEmpty ? null : matches.first;
  }
}
