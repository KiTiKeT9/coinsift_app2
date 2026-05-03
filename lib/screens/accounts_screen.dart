import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accounts_provider.dart';
import '../models/account.dart';
import '../utils/app_colors.dart';
import '../utils/app_utils.dart';
import '../utils/constants.dart';
import '../widgets/account_card.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Счета'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddAccountDialog(context),
          ),
        ],
      ),
      body: Consumer<AccountsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    size: 100,
                    color: AppColors.textLight.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Нет счетов',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Добавьте первый счёт для начала',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddAccountDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить счёт'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadAccounts(),
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              children: [
                // Total Balance Summary
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            'Общий баланс',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppUtils.formatCurrency(provider.totalBalance),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _SummaryItem(
                                icon: Icons.credit_card,
                                label: 'Карты',
                                count: provider.accounts
                                    .where((a) => a.accountType == 'debit' || a.accountType == 'credit')
                                    .length,
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: AppColors.textLight.withValues(alpha: 0.3),
                              ),
                              _SummaryItem(
                                icon: Icons.account_balance_wallet,
                                label: 'Наличные',
                                count: provider.accounts
                                    .where((a) => a.accountType == 'cash')
                                    .length,
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: AppColors.textLight.withValues(alpha: 0.3),
                              ),
                              _SummaryItem(
                                icon: Icons.trending_up,
                                label: 'Инвестиции',
                                count: provider.accounts
                                    .where((a) => a.accountType == 'investment')
                                    .length,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Accounts List
                ...provider.activeAccounts.map((account) => Padding(
                  key: Key(account.id),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: AccountCard(
                    accountId: account.id,
                    onTap: () => _showEditAccountDialog(context, account),
                    onDelete: () => _confirmDelete(context, account),
                  ),
                )),

                // Archived Accounts
                if (provider.archivedAccounts.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      'Архивированные',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...provider.archivedAccounts.map((account) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Opacity(
                      opacity: 0.6,
                      child: AccountCard(
                        accountId: account.id,
                        onTap: () => _showEditAccountDialog(context, account),
                        onDelete: () => _confirmDelete(context, account),
                      ),
                    ),
                  )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    final nameController = TextEditingController();
    final balanceController = TextEditingController();
    final cardNumberController = TextEditingController();
    String selectedBank = '';
    String selectedType = 'debit';
    String selectedColor = '#4CAF50';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Новый счёт'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Название',
                    hintText: 'Например: Основная карта',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: balanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Баланс',
                    prefixText: '₽ ',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Тип счёта'),
                  items: const [
                    DropdownMenuItem(value: 'debit', child: Text('Дебетовый')),
                    DropdownMenuItem(value: 'credit', child: Text('Кредитный')),
                    DropdownMenuItem(value: 'cash', child: Text('Наличные')),
                    DropdownMenuItem(value: 'investment', child: Text('Инвестиционный')),
                  ],
                  onChanged: (value) => setDialogState(() => selectedType = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedBank.isEmpty ? null : selectedBank,
                  decoration: const InputDecoration(labelText: 'Банк'),
                  hint: const Text('Выберите банк'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Не указано')),
                    ...RussianBanks.banks.map((bank) => DropdownMenuItem(
                      value: bank['name'],
                      child: Text(bank['name']),
                    )),
                  ],
                  onChanged: (value) => setDialogState(() => selectedBank = value ?? ''),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cardNumberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Номер карты',
                    hintText: '16 цифр',
                  ),
                  maxLength: 19,
                ),
                const SizedBox(height: 16),
                const Text('Цвет карты'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    '#4CAF50', '#2196F3', '#9C27B0', '#E91E63',
                    '#FF5722', '#795548', '#607D8B', '#FFC107'
                  ].map((color) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(int.parse('FF${color.replaceFirst('#', '')}', radix: 16)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == color
                                ? AppColors.textPrimary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  context.read<AccountsProvider>().addAccount(
                    name: nameController.text,
                    balance: double.tryParse(balanceController.text) ?? 0,
                    bankName: selectedBank,
                    accountType: selectedType,
                    cardNumber: cardNumberController.text.replaceAll(' ', ''),
                    color: selectedColor,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAccountDialog(BuildContext context, Account account) {
    final balanceController = TextEditingController(text: account.balance.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Редактировать счёт'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              account.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Баланс',
                prefixText: '₽ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              account.balance = double.tryParse(balanceController.text) ?? 0;
              context.read<AccountsProvider>().updateAccount(account);
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Account account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Удалить счёт?'),
        content: Text('Вы уверены, что хотите удалить счёт "${account.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AccountsProvider>().deleteAccount(account.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
