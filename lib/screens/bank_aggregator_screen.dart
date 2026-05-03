import 'package:flutter/material.dart';
import '../services/belink_service.dart';
import '../services/bank_aggregator_service.dart';
import '../config/api_config.dart';
import '../screens/bank_oauth_screen.dart';
import '../utils/app_colors.dart';
import '../utils/app_utils.dart';
import '../models/bank_models.dart';

class BankAggregatorScreen extends StatefulWidget {
  const BankAggregatorScreen({super.key});

  @override
  State<BankAggregatorScreen> createState() => _BankAggregatorScreenState();
}

class _BankAggregatorScreenState extends State<BankAggregatorScreen> {
  bool _isEnabled = false;
  bool _isLoading = true;
  List<ConnectedBankInfo> _connectedBanks = [];
  List<BelinkAccount> _accounts = [];
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    setState(() => _isLoading = true);

    final enabled = await BankAggregatorService.isEnabled();
    final connectedBanks = await BankAggregatorService.getConnectedBanks();

    List<BelinkAccount> accounts = [];
    List<dynamic> transactions = [];

    if (enabled && connectedBanks.isNotEmpty) {
      accounts = await BelinkService.getAccounts();
      if (accounts.isEmpty) {
        accounts = await BankAggregatorService.getDemoAccounts();
      }

      transactions = await BelinkService.getAllTransactions();
      if (transactions.isEmpty) {
        transactions = await BankAggregatorService.getDemoTransactions();
      }
    }

    setState(() {
      _isEnabled = enabled;
      _connectedBanks = connectedBanks;
      _accounts = accounts;
      _transactions = transactions;
      _isLoading = false;
    });
  }

  Future<void> _toggleEnabled(bool value) async {
    await BankAggregatorService.setEnabled(value);
    if (!value) {
      await BankAggregatorService.disconnectAll();
    }
    await _loadState();
  }

  Future<void> _connectBank(String bankId) async {
    final bankConfig = ApiConfig.SUPPORTED_BANKS[bankId];
    if (bankConfig == null) return;

    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BankOAuthScreen(
          bankConfig: bankConfig,
          onAuthComplete: (success) => Navigator.pop(context, success),
        ),
      ),
    );

    if (success == true) {
      await _loadState();
    }
  }

  Future<void> _disconnectBank(ConnectedBankInfo bank) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Отключить ${bank.bankName}?'),
        content: const Text(
          'Все данные этого банка будут удалены. Вы можете подключить снова в любое время.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Отключить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await BankAggregatorService.removeConnectedBank(bank.bankId, '');
      await _loadState();
    }
  }

  Future<void> _syncAll() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Синхронизация со всеми банками...'),
              ],
            ),
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    await _loadState();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Синхронизировано ${_transactions.length} транзакций из ${_connectedBanks.length} банков'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Агрегатор банков'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Описание
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance,
                            color: AppColors.secondary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Универсальный агрегатор',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Подключайте несколько банков и получайте все транзакции в одном месте. Один интерфейс для всех ваших счетов.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Включить агрегатор'),
                      subtitle: const Text('Универсальный доступ к банкам'),
                      value: _isEnabled,
                      onChanged: _toggleEnabled,
                      activeThumbColor: AppColors.success,
                    ),
                  ],
                ),
              ),
            ),

            if (_isEnabled) ...[
              const SizedBox(height: 24),

              // Подключённые банки
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Подключённые банки',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_connectedBanks.isNotEmpty)
                    TextButton.icon(
                      onPressed: _syncAll,
                      icon: const Icon(Icons.sync, size: 18),
                      label: const Text('Обновить все'),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (_connectedBanks.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.link_off,
                            size: 64,
                            color: AppColors.textLight.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Нет подключённых банков',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Выберите банк ниже для подключения',
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ..._connectedBanks.expand((ConnectedBankInfo bank) { // Явно указываем тип
                  final bankInfo = ApiConfig.SUPPORTED_BANKS[bank.bankId];
                  if (bankInfo == null) return [];

                  return [
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Color(bankInfo.color).withValues(alpha: 0.1), // Используем Color()
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  bankInfo.icon,
                                  style: const TextStyle(fontSize: 32),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bank.bankName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Подключён ${AppUtils.formatDate(bank.connectedAt)}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.link_off, color: AppColors.error),
                              onPressed: () => _disconnectBank(bank),
                            ),
                          ],
                        ),
                      ),
                    )
                  ];
                }),

              if (_accounts.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Мои счета',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                ..._accounts.map((account) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    account.bankName,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    account.typeLabel,
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          AppUtils.formatCurrency(account.balance),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
              ],

              if (_transactions.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Последние транзакции',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                ..._transactions.map((tx) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (tx.type == 'income'
                            ? AppColors.success
                            : AppColors.error)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        tx.type == 'income'
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        color: tx.type == 'income'
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                    title: Text(tx.description ?? 'Транзакция'),
                    subtitle: Text(
                      '${tx.category} • ${AppUtils.formatDate(tx.date)}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: Text(
                      '${tx.type == 'income' ? '+' : ''}${AppUtils.formatCurrency(tx.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: tx.type == 'income'
                            ? AppColors.success
                            : AppColors.error,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )),
              ],

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Доступные банки для подключения
              const Text(
                'Доступные банки',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              ...ApiConfig.SUPPORTED_BANKS.values.where((bank) => bank.supported).map((bank) {
                final isConnected = _connectedBanks.any((ConnectedBankInfo cb) => cb.bankId == bank.id); // Явно указываем тип

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    enabled: !isConnected && bank.supported,
                    leading: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Color(bank.color).withValues(alpha: 0.1), // Используем Color()
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          bank.icon,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                    title: Text(
                      bank.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      isConnected ? '✓ Подключён' : bank.authUrl.isEmpty ? 'Скоро' : bank.fullName,
                      style: TextStyle(
                        color: isConnected ? AppColors.success : AppColors.textSecondary,
                      ),
                    ),
                    trailing: isConnected
                        ? const Icon(Icons.check_circle, color: AppColors.success)
                        : bank.supported && bank.authUrl.isNotEmpty
                        ? ElevatedButton(
                      onPressed: () => _connectBank(bank.id),
                      child: const Text('Подключить'),
                    )
                        : const Chip(
                      label: Text('Скоро'),
                      backgroundColor: AppColors.textLight,
                      labelStyle: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}