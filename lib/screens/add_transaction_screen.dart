import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:intl/intl.dart';
import '../providers/accounts_provider.dart';
import '../providers/transactions_provider.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../utils/app_utils.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  String _transactionType = 'expense';
  List<Map<String, dynamic>> _categories = TransactionCategories.expenseCategories;
  String? _selectedCategory;

  void _onTypeChanged(String? value) {
    setState(() {
      _transactionType = value ?? 'expense';
      _categories = value == 'income'
          ? TransactionCategories.incomeCategories
          : TransactionCategories.expenseCategories;
      _selectedCategory = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая транзакция'),
        actions: [
          TextButton(
            onPressed: _submitForm,
            child: const Text(
              'Сохранить',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: FormBuilder(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Transaction Type Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Тип операции',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _TypeSelector(
                            title: 'Расход',
                            icon: Icons.arrow_upward,
                            color: AppColors.expense,
                            isSelected: _transactionType == 'expense',
                            onTap: () => _onTypeChanged('expense'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TypeSelector(
                            title: 'Доход',
                            icon: Icons.arrow_downward,
                            color: AppColors.income,
                            isSelected: _transactionType == 'income',
                            onTap: () => _onTypeChanged('income'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Amount Field
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Сумма',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FormBuilderTextField(
                      name: 'amount',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        prefixText: '₽ ',
                        prefixStyle: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        border: InputBorder.none,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите сумму';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Некорректное число';
                        }
                        if (double.parse(value) <= 0) {
                          return 'Минимум 0.01';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Account Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Consumer<AccountsProvider>(
                  builder: (context, accountsProvider, _) {
                    return FormBuilderDropdown<String>(
                      name: 'account',
                      decoration: const InputDecoration(
                        labelText: 'Счёт',
                        prefixIcon: Icon(Icons.account_balance),
                      ),
                      items: accountsProvider.activeAccounts.map((account) {
                        return DropdownMenuItem(
                          value: account.id,
                          child: Text('${account.name} (${AppUtils.formatCurrency(account.balance)})'),
                        );
                      }).toList(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Выберите счёт';
                        }
                        return null;
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Категория',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((category) {
                        final categoryName = category['name'] as String;
                        final isSelected = _selectedCategory == categoryName;
                        
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = categoryName;
                            });
                          },
                          child: ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(category['icon'] as String, style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 6),
                                Text(categoryName),
                              ],
                            ),
                            selected: isSelected,
                            showCheckmark: false,
                            selectedColor: AppColors.primary.withValues(alpha: isDark ? 0.28 : 0.18),
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.6)
                                  : Colors.transparent,
                            ),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_selectedCategory == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Выберите категорию',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Merchant Name
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FormBuilderTextField(
                  name: 'merchant',
                  decoration: const InputDecoration(
                    labelText: 'Место (необязательно)',
                    prefixIcon: Icon(Icons.store),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FormBuilderTextField(
                  name: 'description',
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий',
                    prefixIcon: Icon(Icons.note),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Date
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FormBuilderDateTimePicker(
                  name: 'date',
                  initialValue: DateTime.now(),
                  decoration: const InputDecoration(
                    labelText: 'Дата',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  inputType: InputType.date,
                  format: DateFormat('dd.MM.yyyy'),
                  validator: (value) {
                    if (value == null) {
                      return 'Выберите дату';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  void _submitForm() {
    _formKey.currentState?.save();
    final isValid = _formKey.currentState?.validate() ?? false;
    
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите категорию'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    if (!isValid) return;

    final formData = _formKey.currentState!.value;
    final accountId = formData['account'] as String?;
    final amountStr = formData['amount'] as String?;
    
    if (accountId == null || amountStr == null) return;

    context.read<TransactionsProvider>().addTransaction(
      accountId: accountId,
      amount: double.parse(amountStr),
      type: _transactionType,
      category: _selectedCategory!,
      description: formData['description'] as String? ?? '',
      merchantName: formData['merchant'] as String?,
      date: formData['date'] as DateTime?,
    ).then((_) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_transactionType == 'income' ? 'Доход добавлен' : 'Расход добавлен'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }
}

class _TypeSelector extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeSelector({
    required this.title,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : AppColors.textSecondary, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? color : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
