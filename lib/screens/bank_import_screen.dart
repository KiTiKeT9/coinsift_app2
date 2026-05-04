import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../providers/accounts_provider.dart';
import '../providers/transactions_provider.dart';
import '../services/bank_statement_import_service.dart';
import '../utils/app_colors.dart';
import '../widgets/bank_logo.dart';

/// Экран импорта банковских выписок.
///
/// Поток: пользователь выбирает банк → видит пошаговые инструкции
/// "как выгрузить выписку" → выбирает счёт назначения → выбирает
/// файл (CSV/XLSX/OFX) → импорт идёт через
/// [TransactionsProvider.bulkImport] с дедупликацией.
class BankImportScreen extends StatefulWidget {
  const BankImportScreen({super.key});

  @override
  State<BankImportScreen> createState() => _BankImportScreenState();
}

class _BankImportScreenState extends State<BankImportScreen> {
  String _bankId = SupportedBanks.all.first.id;
  String? _accountId;
  File? _file;
  bool _busy = false;
  ImportResult? _result;
  BulkImportStats? _stats;

  BankFormat get _bank => SupportedBanks.byId(_bankId);

  Future<void> _pickFile() async {
    final f = await BankStatementImportService.pickStatementFile();
    if (f != null) setState(() => _file = f);
  }

  Future<void> _import() async {
    final accountId = _accountId;
    final file = _file;
    if (accountId == null || file == null) return;

    setState(() {
      _busy = true;
      _result = null;
      _stats = null;
    });

    final result = await BankStatementImportService.importFromFile(
      file,
      accountId: accountId,
      bankId: _bankId,
    );

    BulkImportStats? stats;
    if (result.success && result.transactions.isNotEmpty && mounted) {
      stats = await context
          .read<TransactionsProvider>()
          .bulkImport(result.transactions);
    }

    if (!mounted) return;
    setState(() {
      _result = result;
      _stats = stats;
      _busy = false;
    });

    if (result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(stats == null
              ? 'Импорт завершён'
              : 'Добавлено ${stats.added}, '
                  'подтверждено черновиков ${stats.merged}, '
                  'дублей пропущено ${stats.skipped}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        context.watch<AccountsProvider>().activeAccounts;
    return Scaffold(
      appBar: AppBar(title: const Text('Импорт выписок')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BankPicker(
            current: _bankId,
            onSelected: (id) => setState(() => _bankId = id),
          ),
          const SizedBox(height: 16),
          _InstructionsCard(bank: _bank),
          const SizedBox(height: 16),
          _AccountPicker(
            accounts: accounts,
            value: _accountId,
            onChanged: (v) => setState(() => _accountId = v),
          ),
          const SizedBox(height: 16),
          _FilePickerTile(
            file: _file,
            allowedExtensions: _bank.supportedExtensions,
            onPick: _pickFile,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed:
                _busy || _file == null || _accountId == null ? null : _import,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_busy ? 'Импорт...' : 'Импортировать'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 24),
            _ResultCard(result: _result!, stats: _stats),
          ],
        ],
      ),
    );
  }
}

class _BankPicker extends StatelessWidget {
  const _BankPicker({required this.current, required this.onSelected});

  final String current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: SupportedBanks.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final b = SupportedBanks.all[i];
          final selected = b.id == current;
          return InkWell(
            onTap: () => onSelected(b.id),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 92,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).dividerColor,
                  width: selected ? 2 : 1,
                ),
                color: selected
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.08)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BankLogo(
                    bankName: b.shortName,
                    fallbackColorHex: b.colorHex,
                    size: 36,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    b.shortName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({required this.bank});

  final BankFormat bank;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Как выгрузить выписку — ${bank.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < bank.exportSteps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.15),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(bank.exportSteps[i])),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Поддерживаемые форматы: ${bank.supportedExtensions.join(', ').toUpperCase()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.accounts,
    required this.value,
    required this.onChanged,
  });

  final List<Account> accounts;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return Card(
        color: AppColors.warning.withValues(alpha: 0.08),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Сначала добавьте счёт в разделе «Счета», '
            'чтобы было куда импортировать транзакции.',
          ),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Счёт назначения',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final a in accounts)
          DropdownMenuItem(
            value: a.id,
            child: Text('${a.name} • ${a.balance.toStringAsFixed(0)} ${a.currency}'),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _FilePickerTile extends StatelessWidget {
  const _FilePickerTile({
    required this.file,
    required this.allowedExtensions,
    required this.onPick,
  });

  final File? file;
  final List<String> allowedExtensions;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: file != null
                ? AppColors.success
                : Theme.of(context).dividerColor,
            width: file != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              file != null
                  ? Icons.insert_drive_file_outlined
                  : Icons.cloud_upload_outlined,
              size: 36,
              color: file != null
                  ? AppColors.success
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file != null ? 'Файл выбран' : 'Выбрать файл выписки',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    file != null
                        ? file!.path.split(Platform.pathSeparator).last
                        : 'Поддерживаются ${allowedExtensions.join(', ').toUpperCase()}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.stats});

  final ImportResult result;
  final BulkImportStats? stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error_outline,
                  color: result.success ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  result.success ? 'Импорт завершён' : 'Ошибка импорта',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!result.success)
              Text(result.error ?? 'Неизвестная ошибка',
                  style: const TextStyle(color: AppColors.error))
            else ...[
              _row('Всего строк в файле', result.totalRows.toString()),
              _row('Распознано', result.importedRows.toString()),
              _row('Не распознано', result.skippedRows.toString()),
              if (stats != null) ...[
                const Divider(height: 24),
                _row('Добавлено новых', stats!.added.toString()),
                _row('Подтверждено черновиков', stats!.merged.toString()),
                _row('Дубликатов пропущено', stats!.skipped.toString()),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
