import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../models/calculator_record.dart';
import '../services/database_service.dart';
import '../services/banks_api_service.dart';
import '../utils/app_utils.dart';
import '../utils/app_colors.dart';
import '../widgets/bank_logo.dart';

class CalculatorsScreen extends StatefulWidget {
  const CalculatorsScreen({super.key});

  @override
  State<CalculatorsScreen> createState() => _CalculatorsScreenState();
}

class _CalculatorsScreenState extends State<CalculatorsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _banksService = BanksApiService();
  bool _isLoadingRates = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBankRates();
  }

  Future<void> _loadBankRates() async {
    setState(() => _isLoadingRates = true);
    await _banksService.getBankRates(forceRefresh: true);
    setState(() => _isLoadingRates = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Калькуляторы'),
        actions: [
          IconButton(
            icon: _isLoadingRates
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isLoadingRates ? null : _loadBankRates,
            tooltip: 'Обновить ставки',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              _showComparisonDialog(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'mortgage', child: Text('Ипотека')),
              const PopupMenuItem(value: 'loan', child: Text('Кредит')),
              const PopupMenuItem(value: 'deposit', child: Text('Вклад')),
            ],
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'Сравнить банки',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ипотека'),
            Tab(text: 'Вклад'),
            Tab(text: 'Кредит'),
          ],
        ),
      ),
      body: _isLoadingRates && _banksService.cachedRates.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                MortgageCalculator(banksService: _banksService),
                DepositCalculator(banksService: _banksService),
                LoanCalculator(banksService: _banksService),
              ],
            ),
    );
  }

  void _showComparisonDialog(String productType) {
    final comparisons = _banksService.compareBanks(productType);
    final bestRate = _banksService.getBestRate(productType);

    String title = '';
    String rateLabel = '';
    switch (productType) {
      case 'mortgage':
        title = 'Сравнение ипотеки';
        rateLabel = 'Ставка';
        break;
      case 'loan':
        title = 'Сравнение кредитов';
        rateLabel = 'Ставка';
        break;
      case 'deposit':
        title = 'Сравнение вкладов';
        rateLabel = 'Доходность';
        break;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_banksService.lastUpdate != null)
                Text(
                  'Обновлено: ${AppUtils.formatDateTime(_banksService.lastUpdate!)}',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 16),
              if (bestRate != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Лучшее предложение: ${bestRate.bankName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: comparisons.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = comparisons[index];
                    final bank = item['bank'] as dynamic;
                    final rate = item['rate'] as double;
                    final isBest = item['isBest'] as bool;

                    return ListTile(
                      leading: BankLogo(
                        bankName: bank.bankName.toString(),
                        fallbackColorHex: bank.color.toString(),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              bank.bankName.toString(),
                              style: TextStyle(
                                fontWeight: isBest ? FontWeight.bold : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isBest) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Лучше',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${rate.toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isBest
                                  ? AppColors.success
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            rateLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MortgageCalculator extends StatefulWidget {
  final BanksApiService banksService;

  const MortgageCalculator({super.key, required this.banksService});

  @override
  State<MortgageCalculator> createState() => _MortgageCalculatorState();
}

class _MortgageCalculatorState extends State<MortgageCalculator> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '5000000');
  final _initialPaymentController = TextEditingController(text: '1000000');
  final _termController = TextEditingController(text: '20');
  final _rateController = TextEditingController();
  String _selectedBank = 'СберБанк';

  @override
  void initState() {
    super.initState();
    _updateRateFromBank();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _initialPaymentController.dispose();
    _termController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _updateRateFromBank() {
    final bank = widget.banksService.cachedRates.firstWhere(
      (b) => b.bankName == _selectedBank,
      orElse: () => widget.banksService.cachedRates.first,
    );
    _rateController.text = bank.mortgageRate.toStringAsFixed(2);
  }

  Map<String, dynamic> _calculateMortgage() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final initialPayment = double.tryParse(_initialPaymentController.text) ?? 0;
    final termYears = int.tryParse(_termController.text) ?? 0;
    final rate = double.tryParse(_rateController.text) ?? 0;

    final loanAmount = amount - initialPayment;
    final monthlyRate = rate / 100 / 12;
    final totalMonths = termYears * 12;

    double monthlyPayment = 0;
    if (monthlyRate > 0 && totalMonths > 0) {
      monthlyPayment = loanAmount *
          (monthlyRate * math.pow(1 + monthlyRate, totalMonths)) /
          (math.pow(1 + monthlyRate, totalMonths) - 1);
    }

    final totalPayment = monthlyPayment * totalMonths;
    final totalInterest = totalPayment - loanAmount;

    return {
      'loanAmount': loanAmount,
      'monthlyPayment': monthlyPayment,
      'totalPayment': totalPayment,
      'totalInterest': totalInterest,
    };
  }

  @override
  Widget build(BuildContext context) {
    final result = _calculateMortgage();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bank Selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Выберите банк',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Ставка: ${_rateController.text}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBank,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(
                        Icons.account_balance,
                        color: AppColors.primary,
                      ),
                    ),
                    items: widget.banksService.cachedRates
                        .map((bank) => DropdownMenuItem<String>(
                              value: bank.bankName,
                              child: Text(bank.bankName),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedBank = value ?? '';
                        _updateRateFromBank();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Form Fields
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _amountController,
                      label: 'Стоимость недвижимости',
                      prefix: '₽',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _initialPaymentController,
                      label: 'Первоначальный взнос',
                      prefix: '₽',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _termController,
                            label: 'Срок (лет)',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _rateController,
                            label: 'Ставка (%)',
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Results
          _buildResultsCard(result),
          const SizedBox(height: 16),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _saveCalculation(result),
              icon: const Icon(Icons.save),
              label: const Text('Сохранить расчёт'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    TextInputType keyboardType = const TextInputType.numberWithOptions(decimal: true),
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix != null ? '$prefix ' : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildResultsCard(Map<String, dynamic> result) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Результаты расчёта',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _ResultRow(
              label: 'Ежемесячный платёж',
              value: AppUtils.formatCurrency(result['monthlyPayment']),
              isPrimary: true,
            ),
            const SizedBox(height: 16),
            _ResultRow(
              label: 'Сумма кредита',
              value: AppUtils.formatCurrency(result['loanAmount']),
            ),
            const SizedBox(height: 16),
            _ResultRow(
              label: 'Общая выплата',
              value: AppUtils.formatCurrency(result['totalPayment']),
            ),
            const SizedBox(height: 16),
            _ResultRow(
              label: 'Проценты',
              value: AppUtils.formatCurrency(result['totalInterest']),
              valueColor: AppColors.warning,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  void _saveCalculation(Map<String, dynamic> result) {
    final record = CalculatorRecord(
      id: const Uuid().v4(),
      type: 'mortgage',
      bankName: _selectedBank,
      amount: double.tryParse(_amountController.text) ?? 0,
      interestRate: double.tryParse(_rateController.text) ?? 0,
      termMonths: (int.tryParse(_termController.text) ?? 0) * 12,
      calculationDate: DateTime.now(),
      monthlyPayment: result['monthlyPayment'],
      totalPayment: result['totalPayment'],
      totalInterest: result['totalInterest'],
      additionalData: {
        'initialPayment': double.tryParse(_initialPaymentController.text) ?? 0,
      },
    );

    DatabaseService().saveCalculation(record);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Расчёт сохранён'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}

class DepositCalculator extends StatefulWidget {
  final BanksApiService banksService;

  const DepositCalculator({super.key, required this.banksService});

  @override
  State<DepositCalculator> createState() => _DepositCalculatorState();
}

class _DepositCalculatorState extends State<DepositCalculator> {
  final _amountController = TextEditingController(text: '1000000');
  final _termController = TextEditingController(text: '12');
  final _rateController = TextEditingController();
  String _selectedBank = 'СберБанк';
  bool _capitalization = true;

  @override
  void initState() {
    super.initState();
    _updateRateFromBank();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _termController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _updateRateFromBank() {
    final bank = widget.banksService.cachedRates.firstWhere(
      (b) => b.bankName == _selectedBank,
      orElse: () => widget.banksService.cachedRates.first,
    );
    _rateController.text = bank.depositRate.toStringAsFixed(2);
  }

  Map<String, dynamic> _calculateDeposit() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final termMonths = int.tryParse(_termController.text) ?? 0;
    final rate = double.tryParse(_rateController.text) ?? 0;

    double totalAmount = amount;
    double totalInterest = 0;

    if (_capitalization) {
      for (int i = 0; i < termMonths; i++) {
        final monthlyInterest = totalAmount * (rate / 100 / 12);
        totalAmount += monthlyInterest;
        totalInterest += monthlyInterest;
      }
    } else {
      totalInterest = amount * (rate / 100) * (termMonths / 12);
      totalAmount = amount + totalInterest;
    }

    final monthlyIncome = totalInterest / termMonths;

    return {
      'totalAmount': totalAmount,
      'totalInterest': totalInterest,
      'monthlyIncome': monthlyIncome,
    };
  }

  @override
  Widget build(BuildContext context) {
    final result = _calculateDeposit();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Выберите банк',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Ставка: ${_rateController.text}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBank,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(
                        Icons.account_balance,
                        color: AppColors.success,
                      ),
                    ),
                    items: widget.banksService.cachedRates
                        .map((bank) => DropdownMenuItem<String>(
                              value: bank.bankName,
                              child: Text(bank.bankName),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedBank = value ?? '';
                        _updateRateFromBank();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _amountController,
                    label: 'Сумма вклада',
                    prefix: '₽',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _termController,
                    label: 'Срок (месяцев)',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _rateController,
                    label: 'Процентная ставка (%)',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Капитализация процентов'),
                    subtitle: const Text('Сложный процент'),
                    value: _capitalization,
                    onChanged: (value) => setState(() => _capitalization = value),
                    activeThumbColor: AppColors.success,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          _buildResultsCard(result),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    TextInputType keyboardType = const TextInputType.numberWithOptions(decimal: true),
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix != null ? '$prefix ' : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildResultsCard(Map<String, dynamic> result) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.success, Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Доходность вклада',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _ResultRow(
              label: 'Итоговая сумма',
              value: AppUtils.formatCurrency(result['totalAmount']),
              isPrimary: true,
            ),
            const SizedBox(height: 16),
            _ResultRow(
              label: 'Начисленные проценты',
              value: AppUtils.formatCurrency(result['totalInterest']),
            ),
            const SizedBox(height: 16),
            _ResultRow(
              label: 'Ежемесячный доход',
              value: AppUtils.formatCurrency(result['monthlyIncome']),
              valueColor: AppColors.income,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }
}

class LoanCalculator extends StatefulWidget {
  final BanksApiService banksService;

  const LoanCalculator({super.key, required this.banksService});

  @override
  State<LoanCalculator> createState() => _LoanCalculatorState();
}

class _LoanCalculatorState extends State<LoanCalculator> {
  final _amountController = TextEditingController(text: '500000');
  final _termController = TextEditingController(text: '12');
  final _rateController = TextEditingController();
  String _selectedBank = 'СберБанк';

  @override
  void initState() {
    super.initState();
    _updateRateFromBank();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _termController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _updateRateFromBank() {
    final bank = widget.banksService.cachedRates.firstWhere(
      (b) => b.bankName == _selectedBank,
      orElse: () => widget.banksService.cachedRates.first,
    );
    _rateController.text = bank.loanRate.toStringAsFixed(2);
  }

  Map<String, dynamic> _calculateLoan() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final termMonths = int.tryParse(_termController.text) ?? 0;
    final rate = double.tryParse(_rateController.text) ?? 0;

    final monthlyRate = rate / 100 / 12;
    double monthlyPayment = 0;

    if (monthlyRate > 0 && termMonths > 0) {
      monthlyPayment = amount *
          (monthlyRate * math.pow(1 + monthlyRate, termMonths)) /
          (math.pow(1 + monthlyRate, termMonths) - 1);
    }

    final totalPayment = monthlyPayment * termMonths;
    final totalInterest = totalPayment - amount;

    return {
      'monthlyPayment': monthlyPayment,
      'totalPayment': totalPayment,
      'totalInterest': totalInterest,
    };
  }

  @override
  Widget build(BuildContext context) {
    final result = _calculateLoan();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Выберите банк',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Ставка: ${_rateController.text}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBank,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(
                        Icons.account_balance,
                        color: AppColors.secondary,
                      ),
                    ),
                    items: widget.banksService.cachedRates
                        .map((bank) => DropdownMenuItem<String>(
                              value: bank.bankName,
                              child: Text(bank.bankName),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedBank = value ?? '';
                        _updateRateFromBank();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _amountController,
                    label: 'Сумма кредита',
                    prefix: '₽',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _termController,
                    label: 'Срок (месяцев)',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _rateController,
                    label: 'Процентная ставка (%)',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          _buildResultsCard(result),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _saveCalculation(result),
              icon: const Icon(Icons.save),
              label: const Text('Сохранить расчёт'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    TextInputType keyboardType = const TextInputType.numberWithOptions(decimal: true),
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix != null ? '$prefix ' : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildResultsCard(Map<String, dynamic> result) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.secondary, AppColors.secondaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Расчёт кредита',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _ResultRow(
              label: 'Ежемесячный платёж',
              value: AppUtils.formatCurrency(result['monthlyPayment']),
              isPrimary: true,
            ),
            const SizedBox(height: 16),
            _ResultRow(
              label: 'Общая выплата',
              value: AppUtils.formatCurrency(result['totalPayment']),
            ),
            const SizedBox(height: 16),
            _ResultRow(
              label: 'Проценты',
              value: AppUtils.formatCurrency(result['totalInterest']),
              valueColor: AppColors.warning,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  void _saveCalculation(Map<String, dynamic> result) {
    final record = CalculatorRecord(
      id: const Uuid().v4(),
      type: 'loan',
      bankName: _selectedBank,
      amount: double.tryParse(_amountController.text) ?? 0,
      interestRate: double.tryParse(_rateController.text) ?? 0,
      termMonths: int.tryParse(_termController.text) ?? 0,
      calculationDate: DateTime.now(),
      monthlyPayment: result['monthlyPayment'],
      totalPayment: result['totalPayment'],
      totalInterest: result['totalInterest'],
    );

    DatabaseService().saveCalculation(record);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Расчёт сохранён'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isPrimary;
  final Color? valueColor;

  const _ResultRow({
    required this.label,
    required this.value,
    this.isPrimary = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary ? Colors.white.withValues(alpha: 0.9) : Colors.white70,
              fontSize: isPrimary ? 14 : 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: isPrimary ? 24 : 16,
            fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
