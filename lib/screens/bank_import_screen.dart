import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bank_statement_import_service.dart';
import '../providers/transactions_provider.dart';
import '../utils/app_colors.dart';


class BankImportScreen extends StatefulWidget {
  const BankImportScreen({super.key});

  @override
  State<BankImportScreen> createState() => _BankImportScreenState();
}

class _BankImportScreenState extends State<BankImportScreen> {
  bool _isEnabled = false;
  File? _selectedFile;
  bool _isImporting = false;
  ImportResult? _lastResult;
  String _selectedBank = 'universal';

  final Map<String, String> _bankOptions = {
    'universal': 'Универсальный (авто)',
    'tinkoff': 'Тинькофф',
    'sber': 'Сбербанк',
    'alfa': 'Альфа-Банк',
    'vtb': 'ВТБ',
  };

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final enabled = await BankStatementImportService.isEnabled();
    setState(() => _isEnabled = enabled);
  }

  Future<void> _toggleEnabled(bool value) async {
    await BankStatementImportService.setEnabled(value);
    setState(() => _isEnabled = value);
  }

  Future<void> _pickFile() async {
    final file = await BankStatementImportService.pickStatementFile();
    if (file != null) {
      setState(() => _selectedFile = file);
    }
  }

  Future<void> _importFile() async {
    if (_selectedFile == null) return;

    setState(() => _isImporting = true);

    final result = await BankStatementImportService.importFromFile(
      _selectedFile!,
      accountId: 'imported_${DateTime.now().millisecondsSinceEpoch}',
    );

    setState(() {
      _lastResult = result;
      _isImporting = false;
    });

    if (result.success && result.transactions.isNotEmpty) {
      if (!mounted) return;
      // Добавляем транзакции в приложение
      final transactionsProvider = context.read<TransactionsProvider>();
      
      for (final tx in result.transactions) {
        await transactionsProvider.addTransaction(
          accountId: tx.accountId,
          amount: tx.amount,
          category: tx.category,
          description: tx.description,
          type: tx.type,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Импортировано ${result.transactions.length} транзакций'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Как экспортировать выписку'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedBank,
                decoration: const InputDecoration(labelText: 'Выберите банк'),
                items: _bankOptions.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedBank = value!),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  BankStatementImportService.getExportInstructions(_selectedBank),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Импорт выписок'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showInstructions,
            tooltip: 'Инструкция',
          ),
        ],
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
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.upload_file,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Импорт банковских выписок',
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
                      'Загружайте выписки из банков в формате CSV или Excel. '
                      'Приложение автоматически распознает транзакции и категории.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Включить импорт'),
                      subtitle: const Text('Загрузка выписок из файлов'),
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

              // Выбор файла
              const Text(
                'Выберите файл выписки',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedFile != null
                          ? AppColors.success
                          : AppColors.textLight.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: _selectedFile != null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                  size: 48,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Файл выбран',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedFile!.path.split('/').last,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Icon(
                                  Icons.cloud_upload,
                                  color: AppColors.primary,
                                  size: 48,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Нажмите для выбора файла',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Поддерживаются CSV, XLSX, XLS',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              if (_selectedFile != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isImporting ? null : _importFile,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.import_export),
                    label: Text(_isImporting ? 'Импорт...' : 'Импортировать'),
                  ),
                ),
              ],

              if (_lastResult != null) ...[
                const SizedBox(height: 24),

                // Результат импорта
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _lastResult!.success
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _lastResult!.success
                                  ? AppColors.success
                                  : AppColors.error,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _lastResult!.success
                                  ? 'Импорт завершён'
                                  : 'Ошибка импорта',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_lastResult!.success) ...[
                          _buildStatRow('Всего строк', _lastResult!.totalRows.toString()),
                          _buildStatRow('Импортировано', _lastResult!.importedRows.toString()),
                          _buildStatRow('Пропущено', _lastResult!.skippedRows.toString()),
                        ] else
                          Text(
                            _lastResult!.error ?? 'Неизвестная ошибка',
                            style: const TextStyle(color: AppColors.error),
                          ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Поддерживаемые форматы
              const Text(
                'Поддерживаемые банки',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              _buildBankSupportCard('Тинькофф', 'CSV, Excel', true),
              _buildBankSupportCard('Сбербанк', 'CSV, Excel', true),
              _buildBankSupportCard('Альфа-Банк', 'CSV', true),
              _buildBankSupportCard('ВТБ', 'CSV, Excel', true),
              _buildBankSupportCard('Другие банки', 'CSV', true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBankSupportCard(String name, String formats, bool supported) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: supported
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.textLight.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            supported ? Icons.check_circle : Icons.block,
            color: supported ? AppColors.success : AppColors.textLight,
          ),
        ),
        title: Text(name),
        subtitle: Text('Форматы: $formats'),
        trailing: supported
            ? const Chip(
                label: Text('Поддерживается'),
                backgroundColor: AppColors.success,
                labelStyle: TextStyle(color: Colors.white),
              )
            : const Chip(
                label: Text('Не поддерживается'),
                backgroundColor: AppColors.textLight,
                labelStyle: TextStyle(color: Colors.white),
              ),
      ),
    );
  }
}
