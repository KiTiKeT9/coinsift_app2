import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/transaction.dart';
import '../providers/accounts_provider.dart';
import '../providers/transactions_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/bank_logo.dart';

/// Экран «Черновики» — операции, распознанные из SMS/push, которые
/// ждут подтверждения пользователем (выбор счёта/категории и
/// учёт в балансе).
class DraftsScreen extends StatelessWidget {
  const DraftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txProv = context.watch<TransactionsProvider>();
    final drafts = List<Transaction>.from(txProv.drafts)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: const Text('Черновики')),
      body: drafts.isEmpty
          ? const _EmptyDrafts()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: drafts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _DraftCard(draft: drafts[i]),
            ),
    );
  }
}

class _EmptyDrafts extends StatelessWidget {
  const _EmptyDrafts();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Нет черновиков',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Сюда попадают операции, распознанные из SMS и push-уведомлений банков. Подтвердите их, чтобы они учитывались в балансе.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftCard extends StatefulWidget {
  const _DraftCard({required this.draft});
  final Transaction draft;

  @override
  State<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<_DraftCard> {
  String? _accountId;

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountsProvider>().activeAccounts;
    _accountId ??= _guessAccount(accounts, widget.draft);

    final isIncome = widget.draft.type == 'income';
    final fmt = DateFormat('dd MMM, HH:mm', 'ru_RU');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BankLogo(
                  bankName: widget.draft.bankId ?? '?',
                  fallbackColorHex: '#9CA3AF',
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.draft.merchantName?.isNotEmpty == true
                            ? widget.draft.merchantName!
                            : (isIncome ? 'Поступление' : 'Списание'),
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${fmt.format(widget.draft.date)} • '
                        '${widget.draft.source ?? 'sms'}'
                        '${widget.draft.cardMask != null ? ' • *${widget.draft.cardMask}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isIncome ? '+' : '−'}'
                  '${widget.draft.amount.toStringAsFixed(2)} '
                  '${widget.draft.currency}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isIncome ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: const InputDecoration(
                labelText: 'Счёт',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final a in accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reject,
                    icon: const Icon(Icons.close),
                    label: const Text('Отклонить'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _accountId == null ? null : _confirm,
                    icon: const Icon(Icons.check),
                    label: const Text('Подтвердить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _guessAccount(List<Account> accounts, Transaction t) {
    if (accounts.isEmpty) return null;
    if (t.cardNumber4Match(accounts) case final id?) return id;
    return accounts.first.id;
  }

  Future<void> _confirm() async {
    final id = _accountId;
    if (id == null) return;
    await context
        .read<TransactionsProvider>()
        .confirmDraft(widget.draft, accountId: id);
  }

  Future<void> _reject() async {
    await context.read<TransactionsProvider>().rejectDraft(widget.draft.id);
  }
}

extension on Transaction {
  /// Пытается сопоставить `cardMask` транзакции с последними 4 цифрами
  /// номера карты у активных счетов. Если есть совпадение — возвращает id.
  String? cardNumber4Match(List<Account> accounts) {
    final mask = cardMask;
    if (mask == null) return null;
    for (final a in accounts) {
      final card = a.cardNumber;
      if (card == null || card.isEmpty) continue;
      final digits = card.replaceAll(RegExp(r'\D'), '');
      if (digits.endsWith(mask)) return a.id;
    }
    return null;
  }
}
