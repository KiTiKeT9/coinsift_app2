import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../providers/transactions_provider.dart';
import '../utils/app_colors.dart';
import '../utils/app_utils.dart';
import '../utils/constants.dart';
import 'skeletons.dart';

class TransactionList extends StatelessWidget {
  final int limit;
  final Function(Transaction)? onTap;

  const TransactionList({
    super.key,
    this.limit = 5,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final transactionsProvider = context.watch<TransactionsProvider>();
    final transactions = transactionsProvider.getRecentTransactions(limit: limit);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (transactionsProvider.isLoading && transactions.isEmpty) {
      return TransactionListSkeleton(itemCount: limit.clamp(3, 5));
    }

    if (transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_rounded, size: 40, color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Пока нет операций',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              SizedBox(height: 6),
              Text(
                'Добавьте первую транзакцию,\nчтобы увидеть аналитику',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textLight, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final isIncome = transaction.type == 'income';
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Dismissible(
            key: Key(transaction.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
            ),
            onDismissed: (_) {
              transactionsProvider.deleteTransaction(transaction.id);
            },
            child: InkWell(
              onTap: onTap != null ? () => onTap!(transaction) : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(transaction.category).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          _getCategoryIcon(transaction.category),
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.merchantName != null && transaction.merchantName!.isNotEmpty
                                ? transaction.merchantName!
                                : transaction.category,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            transaction.merchantName != null && transaction.merchantName!.isNotEmpty
                                ? transaction.category
                                : AppUtils.formatDate(transaction.date),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          (isIncome ? '+ ' : '- ') + AppUtils.formatCurrency(transaction.amount),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isIncome
                                ? AppColors.income
                                : Theme.of(context).colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (transaction.merchantName != null && transaction.merchantName!.isNotEmpty)
                          Text(
                            AppUtils.formatDate(transaction.date),
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
            ),
          )
              .animate()
              .fadeIn(delay: (index * 50).ms, duration: 400.ms)
              .slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    final cat = TransactionCategories.getCategoryByName(category);
    return Color(int.parse((cat['color'] ?? '#94A3B8').replaceFirst('#', 'FF'), radix: 16));
  }

  String _getCategoryIcon(String category) {
    final cat = TransactionCategories.getCategoryByName(category);
    return cat['icon'] ?? '📝';
  }
}

class ExpenseLegend extends StatelessWidget {
  const ExpenseLegend({super.key, this.data});

  /// Если не указано — используется `expensesByCategory` из провайдера.
  final Map<String, double>? data;

  @override
  Widget build(BuildContext context) {
    final source = data ??
        context.watch<TransactionsProvider>().expensesByCategory;

    if (source.isEmpty) return const SizedBox.shrink();

    // Берем топ 4 категории
    final topExpenses = source.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final displayExpenses = topExpenses.take(4).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 8,
      ),
      itemCount: displayExpenses.length,
      itemBuilder: (context, index) {
        final entry = displayExpenses[index];
        final cat = TransactionCategories.getCategoryByName(entry.key);
        final color = Color(int.parse((cat['color'] ?? '#94A3B8').replaceFirst('#', 'FF'), radix: 16));

        return Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    AppUtils.formatCurrency(entry.value),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
