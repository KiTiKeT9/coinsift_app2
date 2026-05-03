import '../models/transaction.dart';
import 'belink_service.dart';
import '../models/bank_models.dart'; // Добавляем импорт для ConnectedBankInfo

/// Универсальный агрегатор банковских API
/// Использует Belink как основной бэкенд
class BankAggregatorService {
  // Делегируем все запросы к BelinkService

  static Future<bool> isEnabled() => BelinkService.isEnabled();

  static Future<void> setEnabled(bool enabled) => BelinkService.setEnabled(enabled);

  static Future<List<ConnectedBankInfo>> getConnectedBanks() =>
      BelinkService.getConnectedBanks();

  static Future<void> saveConnectedBank(ConnectedBankInfo bank) =>
      BelinkService.addConnectedBank(bank);

  static Future<void> removeConnectedBank(String bankId, String accountId) =>
      BelinkService.removeConnectedBank(bankId);

  static Future<void> disconnectAll() => BelinkService.disconnectAll();

  static Future<bool> isBankConnected(String bankId) async {
    final banks = await getConnectedBanks();
    return banks.any((b) => b.bankId == bankId);
  }

  // Демо данные для тестирования
  static Future<List<BelinkAccount>> getDemoAccounts() =>
      BelinkService.getDemoAccounts();

  static Future<List<Transaction>> getDemoTransactions() =>
      BelinkService.getDemoTransactions();
}