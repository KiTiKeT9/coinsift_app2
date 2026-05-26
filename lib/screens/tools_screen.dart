import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/goals_provider.dart';
import '../models/goal.dart';
import '../services/currency_service.dart';
import '../services/banks_api_service.dart';
import '../models/currency_rate.dart';
import '../utils/app_colors.dart';
import '../utils/app_utils.dart';
import 'goal_detail_screen.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('Сервисы'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.flag_rounded), text: 'Цели'),
            Tab(icon: Icon(Icons.currency_exchange), text: 'Курсы'),
            Tab(icon: Icon(Icons.calculate_outlined), text: 'Калькуляторы'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _GoalsTab(),
          _CurrencyTab(),
          _CalculatorsTab(),
        ],
      ),
    );
  }
}

class _GoalsTab extends StatefulWidget {
  const _GoalsTab();

  @override
  State<_GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends State<_GoalsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoalsProvider>().loadGoals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Consumer<GoalsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final active = provider.activeGoals;
          final completed = provider.completedGoals;

          if (active.isEmpty && completed.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🎯', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text(
                    'Нет целей',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Создайте первую финансовую цель',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showAddGoalDialog(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Создать цель'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadGoals(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                if (active.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'АКТИВНЫЕ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  ...active.map((g) => _GoalCard(goal: g, isDark: isDark)),
                ],
                if (completed.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'ЗАВЕРШЁННЫЕ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  ...completed.map((g) => _GoalCard(goal: g, isDark: isDark)),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGoalDialog(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedIcon = '🎯';
    DateTime? deadline;
    String category = 'savings';

    const emojis = ['🎯', '💰', '🏠', '🚗', '✈️', '🎓', '💳', '🏥', '💼', '👶'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.flag_rounded, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Новая цель', style: Theme.of(context).textTheme.titleLarge),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: emojis.map((e) => GestureDetector(
                          onTap: () => setDialogState(() => selectedIcon = e),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: selectedIcon == e
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: selectedIcon == e
                                  ? Border.all(color: AppColors.primary, width: 2)
                                  : null,
                            ),
                            child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: titleCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Название цели',
                          hintText: 'Накопить на машину',
                          prefixIcon: Icon(Icons.edit_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Описание (необязательно)',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: targetCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Сумма цели',
                          prefixIcon: Icon(Icons.monetization_on_outlined),
                          suffixText: '₽',
                        ),
                        validator: (v) {
                          final val = double.tryParse(v?.replaceAll(',', '.') ?? '');
                          return (val == null || val <= 0) ? 'Укажите сумму' : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: deadline ?? DateTime.now().add(const Duration(days: 365)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                            locale: const Locale('ru', 'RU'),
                          );
                          if (picked != null) {
                            setDialogState(() => deadline = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Дедлайн (необязательно)',
                            prefixIcon: const Icon(Icons.calendar_today_rounded),
                            suffixIcon: deadline != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => setDialogState(() => deadline = null),
                                  )
                                : null,
                          ),
                          child: Text(
                            deadline != null
                                ? AppUtils.formatDate(deadline!)
                                : 'Выберите дату',
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Отмена'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {
                              if (!(formKey.currentState?.validate() ?? false)) return;
                              final target = double.tryParse(
                                targetCtrl.text.replaceAll(',', '.'),
                              )!;
                              context.read<GoalsProvider>().addGoal(
                                title: titleCtrl.text.trim(),
                                description: descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                                targetAmount: target,
                                deadline: deadline,
                                iconEmoji: selectedIcon,
                                category: category,
                              );
                              Navigator.pop(ctx);
                            },
                            child: const Text('Создать'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final bool isDark;

  const _GoalCard({required this.goal, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final progress = goal.progressPercent;
    final remaining = goal.remainingAmount;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? AppColors.darkCard : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GoalDetailScreen(goalId: goal.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: goal.isCompleted
                            ? AppColors.success.withValues(alpha: 0.12)
                            : AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(goal.iconEmoji ?? '🎯', style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          if (goal.description != null && goal.description!.isNotEmpty)
                            Text(
                              goal.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (goal.isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 14, color: AppColors.success),
                            SizedBox(width: 4),
                            Text(
                              'Готово',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 10,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        goal.isCompleted
                            ? AppColors.success
                            : goal.isOverdue
                                ? AppColors.error
                                : AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: goal.isCompleted ? AppColors.success : null,
                      ),
                    ),
                    Text(
                      'Осталось ${AppUtils.formatCompactCurrency(remaining, currency: goal.currency)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                if (goal.deadline != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: goal.isOverdue ? AppColors.error : AppColors.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        goal.isOverdue ? 'Просрочено' : 'до ${AppUtils.formatDate(goal.deadline!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: goal.isOverdue ? AppColors.error : AppColors.textLight,
                          fontWeight: goal.isOverdue ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyTab extends StatefulWidget {
  const _CurrencyTab();

  @override
  State<_CurrencyTab> createState() => _CurrencyTabState();
}

class _CurrencyTabState extends State<_CurrencyTab> {
  final _service = CurrencyService();
  List<CurrencyRate> _rates = [];
  bool _loading = true;
  String _baseCurrency = 'USD';
  final _convertAmountCtrl = TextEditingController();
  String _convertFrom = 'USD';
  String _convertTo = 'RUB';
  double _convertResult = 0;

  static const _bankNames = {
    'RUB': 'ЦБ РФ', 'USD': 'ФРС США', 'EUR': 'ЕЦБ',
    'GBP': 'Банк Англии', 'CNY': 'Народный банк Китая',
    'JPY': 'Банк Японии', 'CHF': 'Швейцарский нацбанк',
    'KZT': 'Нацбанк Казахстана', 'BYN': 'Нацбанк Беларуси',
    'AMD': 'ЦБ Армении',
  };

  @override
  void initState() {
    super.initState();
    _loadRates();
    _convertAmountCtrl.addListener(_updateConvertResult);
  }

  @override
  void dispose() {
    _convertAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRates() async {
    setState(() => _loading = true);
    try {
      await _service.fetchRates();
      if (mounted) {
        setState(() {
          _rates = _service.cachedRates ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final cached = _service.cachedRates;
        setState(() {
          _rates = cached ?? [];
          _loading = false;
        });
      }
    }
  }

  void _updateConvertResult() {
    final amount = double.tryParse(_convertAmountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _convertResult = 0);
      return;
    }
    final result = AppUtils.convertAmount(amount, _convertFrom, _convertTo, _rates.map((r) => {'currency': r.currency, 'rate': r.rate}).toList());
    setState(() => _convertResult = result);
  }

  double _getRelativeRate(String currency) {
    if (currency == _baseCurrency) return 1.0;
    final usdRate = _rates.where((r) => r.currency == currency).firstOrNull;
    if (usdRate == null) return 0;
    if (_baseCurrency == 'USD') return usdRate.rate;
    final baseRate = _rates.where((r) => r.currency == _baseCurrency).firstOrNull;
    if (baseRate == null || baseRate.rate == 0) return 0;
    return usdRate.rate / baseRate.rate;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Text('База: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 4),
              DropdownButton<String>(
                value: _baseCurrency,
                underline: const SizedBox(),
                items: CurrencyService.supportedCurrencies.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text('${CurrencyService.getFlag(c)} $c', style: const TextStyle(fontWeight: FontWeight.w700)),
                )).toList(),
                onChanged: (v) => setState(() => _baseCurrency = v!),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadRates,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Курсы к $_baseCurrency', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          if (_service.lastFetch != null)
                            Text('обновлено', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...CurrencyService.supportedCurrencies.where((c) => c != _baseCurrency).map((c) {
                        final rate = _getRelativeRate(c);
                        final flag = CurrencyService.getFlag(c);
                        final bankName = _bankNames[c] ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Text(flag, style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                    Text(bankName, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                                  ],
                                ),
                              ),
                              Text(rate > 0 ? rate.toStringAsFixed(4) : '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Конвертер', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _convertFrom,
                              decoration: const InputDecoration(labelText: 'Из'),
                              items: CurrencyService.supportedCurrencies.map((c) => DropdownMenuItem(
                                value: c,
                                child: Text('${CurrencyService.getFlag(c)} $c'),
                              )).toList(),
                              onChanged: (v) => setState(() { _convertFrom = v!; _updateConvertResult(); }),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward, color: AppColors.textLight),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _convertTo,
                              decoration: const InputDecoration(labelText: 'В'),
                              items: CurrencyService.supportedCurrencies.map((c) => DropdownMenuItem(
                                value: c,
                                child: Text('${CurrencyService.getFlag(c)} $c'),
                              )).toList(),
                              onChanged: (v) => setState(() { _convertTo = v!; _updateConvertResult(); }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _convertAmountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: 'Сумма', prefixIcon: Icon(Icons.monetization_on_outlined)),
                      ),
                      if (_convertResult > 0) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            children: [
                              Text('${_convertAmountCtrl.text} $_convertFrom =', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('${_convertResult.toStringAsFixed(4)} $_convertTo', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: _loadRates,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Обновить курсы'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CalculatorsTab extends StatefulWidget {
  const _CalculatorsTab();

  @override
  State<_CalculatorsTab> createState() => _CalculatorsTabState();
}

class _CalculatorsTabState extends State<_CalculatorsTab>
    with SingleTickerProviderStateMixin {
  late TabController _calcTabController;
  final _banksService = BanksApiService();
  bool _isLoadingRates = false;

  @override
  void initState() {
    super.initState();
    _calcTabController = TabController(length: 3, vsync: this);
    _loadBankRates();
  }

  Future<void> _loadBankRates() async {
    setState(() => _isLoadingRates = true);
    await _banksService.getBankRates(forceRefresh: true);
    setState(() => _isLoadingRates = false);
  }

  @override
  void dispose() {
    _calcTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRates && _banksService.cachedRates.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        TabBar(
          controller: _calcTabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Ипотека'),
            Tab(text: 'Вклад'),
            Tab(text: 'Кредит'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _calcTabController,
            children: [
              _MortgageCalc(banksService: _banksService, onRefresh: _loadBankRates),
              _DepositCalc(banksService: _banksService, onRefresh: _loadBankRates),
              _LoanCalc(banksService: _banksService, onRefresh: _loadBankRates),
            ],
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton.icon(
              onPressed: _isLoadingRates ? null : _loadBankRates,
              icon: _isLoadingRates
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_isLoadingRates ? 'Обновление...' : 'Обновить ставки'),
            ),
          ),
        ),
      ],
    );
  }
}

class _MortgageCalc extends StatefulWidget {
  final BanksApiService banksService;
  final VoidCallback onRefresh;
  const _MortgageCalc({required this.banksService, required this.onRefresh});

  @override
  State<_MortgageCalc> createState() => _MortgageCalcState();
}

class _MortgageCalcState extends State<_MortgageCalc> {
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

  Map<String, dynamic> _calculate() {
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
    return {'loanAmount': loanAmount, 'monthlyPayment': monthlyPayment, 'totalPayment': totalPayment, 'totalInterest': totalPayment - loanAmount};
  }

  @override
  Widget build(BuildContext context) {
    final result = _calculate();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedBank,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.account_balance, color: AppColors.primary)),
                items: widget.banksService.cachedRates.map((b) => DropdownMenuItem(value: b.bankName, child: Text(b.bankName))).toList(),
                onChanged: (v) => setState(() { _selectedBank = v ?? ''; _updateRateFromBank(); }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextField(
                      controller: _amountController,
                      decoration: const InputDecoration(labelText: 'Стоимость недвижимости', prefixText: '₽ '),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _initialPaymentController,
                      decoration: const InputDecoration(labelText: 'Первоначальный взнос', prefixText: '₽ '),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _termController,
                            decoration: const InputDecoration(labelText: 'Срок (лет)'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _rateController,
                            decoration: const InputDecoration(labelText: 'Ставка (%)', suffixText: '%'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Результаты', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _ResultRow(label: 'Ежемесячный платёж', value: AppUtils.formatCurrency(result['monthlyPayment']), isPrimary: true),
                const SizedBox(height: 12),
                _ResultRow(label: 'Сумма кредита', value: AppUtils.formatCurrency(result['loanAmount'])),
                const SizedBox(height: 12),
                _ResultRow(label: 'Общая выплата', value: AppUtils.formatCurrency(result['totalPayment'])),
                const SizedBox(height: 12),
              _ResultRow(label: 'Проценты', value: AppUtils.formatCurrency(result['totalInterest']), valueColor: AppColors.warning),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Обновить ставки'),
          ),
        ),
        const SizedBox(height: 24),
      ],
      ),
    );
  }
}

class _DepositCalc extends StatefulWidget {
  final BanksApiService banksService;
  final VoidCallback onRefresh;
  const _DepositCalc({required this.banksService, required this.onRefresh});

  @override
  State<_DepositCalc> createState() => _DepositCalcState();
}

class _DepositCalcState extends State<_DepositCalc> {
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

  Map<String, dynamic> _calculate() {
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
    return {'totalAmount': totalAmount, 'totalInterest': totalInterest, 'monthlyIncome': totalInterest / (termMonths > 0 ? termMonths : 1)};
  }

  @override
  Widget build(BuildContext context) {
    final result = _calculate();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedBank,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.account_balance, color: AppColors.success)),
                items: widget.banksService.cachedRates.map((b) => DropdownMenuItem(value: b.bankName, child: Text(b.bankName))).toList(),
                onChanged: (v) => setState(() { _selectedBank = v ?? ''; _updateRateFromBank(); }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'Сумма вклада', prefixText: '₽ '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _termController,
                    decoration: const InputDecoration(labelText: 'Срок (месяцев)'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rateController,
                    decoration: const InputDecoration(labelText: 'Ставка (%)', suffixText: '%'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Капитализация'),
                    subtitle: const Text('Сложный процент'),
                    value: _capitalization,
                    onChanged: (v) => setState(() => _capitalization = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.success, Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Доходность', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _ResultRow(label: 'Итоговая сумма', value: AppUtils.formatCurrency(result['totalAmount']), isPrimary: true),
                const SizedBox(height: 12),
                _ResultRow(label: 'Проценты', value: AppUtils.formatCurrency(result['totalInterest'])),
                const SizedBox(height: 12),
              _ResultRow(label: 'Ежемесячный доход', value: AppUtils.formatCurrency(result['monthlyIncome']), valueColor: AppColors.income),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Обновить ставки'),
          ),
        ),
        const SizedBox(height: 24),
      ],
      ),
    );
  }
}

class _LoanCalc extends StatefulWidget {
  final BanksApiService banksService;
  final VoidCallback onRefresh;
  const _LoanCalc({required this.banksService, required this.onRefresh});

  @override
  State<_LoanCalc> createState() => _LoanCalcState();
}

class _LoanCalcState extends State<_LoanCalc> {
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

  Map<String, dynamic> _calculate() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final termMonths = int.tryParse(_termController.text) ?? 0;
    final rate = double.tryParse(_rateController.text) ?? 0;
    final monthlyRate = rate / 100 / 12;
    double monthlyPayment = 0;
    if (monthlyRate > 0 && termMonths > 0) {
      monthlyPayment = amount * (monthlyRate * math.pow(1 + monthlyRate, termMonths)) / (math.pow(1 + monthlyRate, termMonths) - 1);
    }
    final totalPayment = monthlyPayment * termMonths;
    return {'monthlyPayment': monthlyPayment, 'totalPayment': totalPayment, 'totalInterest': totalPayment - amount};
  }

  @override
  Widget build(BuildContext context) {
    final result = _calculate();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedBank,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.account_balance, color: AppColors.secondary)),
                items: widget.banksService.cachedRates.map((b) => DropdownMenuItem(value: b.bankName, child: Text(b.bankName))).toList(),
                onChanged: (v) => setState(() { _selectedBank = v ?? ''; _updateRateFromBank(); }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'Сумма кредита', prefixText: '₽ '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _termController,
                    decoration: const InputDecoration(labelText: 'Срок (месяцев)'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rateController,
                    decoration: const InputDecoration(labelText: 'Ставка (%)', suffixText: '%'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.secondary, AppColors.secondaryDark]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Расчёт кредита', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _ResultRow(label: 'Ежемесячный платёж', value: AppUtils.formatCurrency(result['monthlyPayment']), isPrimary: true),
                const SizedBox(height: 12),
                _ResultRow(label: 'Общая выплата', value: AppUtils.formatCurrency(result['totalPayment'])),
                const SizedBox(height: 12),
              _ResultRow(label: 'Проценты', value: AppUtils.formatCurrency(result['totalInterest']), valueColor: AppColors.warning),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Обновить ставки'),
          ),
        ),
        const SizedBox(height: 24),
      ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isPrimary;
  final Color? valueColor;

  const _ResultRow({required this.label, required this.value, this.isPrimary = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isPrimary ? Colors.white.withValues(alpha: 0.9) : Colors.white70, fontSize: isPrimary ? 14 : 13)),
        Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: isPrimary ? 24 : 16, fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }
}
