// database_service.dart

import 'package:hive_flutter/hive_flutter.dart';

import '../models/account.dart';
import '../models/transaction.dart';
import '../models/user_profile.dart';
import '../models/investment.dart';
import '../models/calculator_record.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Box<Account> _accountsBox;
  late Box<Transaction> _transactionsBox;
  late Box<UserProfile> _userProfileBox;
  late Box<Investment> _investmentsBox;
  late Box<CalculatorRecord> _calculatorBox;

  Future<void> init() async {
    await Hive.initFlutter();

    _accountsBox = await Hive.openBox<Account>('accounts');
    _transactionsBox = await Hive.openBox<Transaction>('transactions');
    _userProfileBox = await Hive.openBox<UserProfile>('user_profile');
    _investmentsBox = await Hive.openBox<Investment>('investments');
    _calculatorBox = await Hive.openBox<CalculatorRecord>('calculators');
  }

  Box<Account> get accountsBox => _accountsBox;
  List<Account> get allAccounts => _accountsBox.values.toList();

  Future<void> addAccount(Account account) async {
    await _accountsBox.put(account.id, account);
  }

  Future<void> updateAccount(Account account) async {
    await _accountsBox.put(account.id, account);
  }

  Future<void> deleteAccount(String id) async {
    await _accountsBox.delete(id);
  }

  Account? getAccount(String id) => _accountsBox.get(id);

  Box<Transaction> get transactionsBox => _transactionsBox;
  List<Transaction> get allTransactions => _transactionsBox.values.toList();

  Future<void> addTransaction(Transaction transaction) async {
    await _transactionsBox.put(transaction.id, transaction);
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await _transactionsBox.put(transaction.id, transaction);
  }

  Future<void> deleteTransaction(String id) async {
    await _transactionsBox.delete(id);
  }

  List<Transaction> getTransactionsByAccount(String accountId) {
    return _transactionsBox.values.where((t) => t.accountId == accountId).toList();
  }

  Box<UserProfile> get userProfileBox => _userProfileBox;
  UserProfile? get userProfile => _userProfileBox.isEmpty ? null : _userProfileBox.getAt(0);

  Future<void> saveUserProfile(UserProfile profile) async {
    await _userProfileBox.put('profile', profile);
  }

  Box<Investment> get investmentsBox => _investmentsBox;
  List<Investment> get allInvestments => _investmentsBox.values.toList();

  Future<void> addInvestment(Investment investment) async {
    await _investmentsBox.put(investment.id, investment);
  }

  Future<void> updateInvestment(Investment investment) async {
    await _investmentsBox.put(investment.id, investment);
  }

  Future<void> deleteInvestment(String id) async {
    await _investmentsBox.delete(id);
  }

  Box<CalculatorRecord> get calculatorBox => _calculatorBox;
  List<CalculatorRecord> get allCalculations => _calculatorBox.values.toList();

  Future<void> saveCalculation(CalculatorRecord record) async {
    await _calculatorBox.put(record.id, record);
  }

  Future<void> deleteCalculation(String id) async {
    await _calculatorBox.delete(id);
  }

  Future<void> clearAllData() async {
    await _accountsBox.clear();
    await _transactionsBox.clear();
    await _userProfileBox.clear();
    await _investmentsBox.clear();
    await _calculatorBox.clear();
  }
}
