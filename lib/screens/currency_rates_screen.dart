import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/currency_service.dart';
import '../models/currency_rate.dart';
import '../utils/app_colors.dart';
import 'package:intl/intl.dart';

class CurrencyRatesScreen extends StatefulWidget {
  const CurrencyRatesScreen({super.key});

  @override
  State<CurrencyRatesScreen> createState() => _CurrencyRatesScreenState();
}

class _CurrencyRatesScreenState extends State<CurrencyRatesScreen> {
  final _service = CurrencyService();
  List<CurrencyRate> _rates = [];
  bool _loading = true;
  String _baseCurrency = 'RUB';
  final _convertAmountCtrl = TextEditingController();
  String _convertFrom = 'USD';
  String _convertTo = 'RUB';
  double _convertResult = 0;

  static const _bankNames = {
    'RUB': 'ЦБ РФ', 'USD': 'ФРС США', 'EUR': 'ЕЦБ',
    'GBP': 'Банк Англии', 'CNY': 'Народный банк Китая',
    'JPY': 'Банк Японии', 'CHF': 'Швейцарский нацбанк',
    'KZT': 'Нацбанк Казахстана', 'BYN': 'Нацбанк Беларуси',
    'AMD': 'Центробанк Армении',
  };

  static const _bankSupported = {
    'RUB', 'USD', 'EUR', 'GBP', 'CNY',
  };

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  @override
  void dispose() {
    _convertAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRates() async {
    setState(() => _loading = true);
    final rates = await _service.fetchRates(base: _baseCurrency);
    if (mounted) {
      setState(() {
        _rates = rates;
        _loading = false;
      });
    }
  }

  void _calculateConversion() {
    final amount = double.tryParse(_convertAmountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;
    _service.convert(amount, _convertFrom, _convertTo).then((result) {
      if (mounted && result != null) {
        setState(() => _convertResult = result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayCurrency = context.watch<UserProfileProvider>().displayCurrency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Курсы валют'),
        actions: [
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${CurrencyService.getFlag(_baseCurrency)} $_baseCurrency',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            onSelected: (base) {
              _baseCurrency = base;
              _loadRates();
            },
            itemBuilder: (_) => CurrencyService.supportedCurrencies.map((c) =>
              PopupMenuItem(
                value: c,
                child: Text('${CurrencyService.getFlag(c)} $c'),
              ),
            ).toList(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRates,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _rates.isEmpty
                ? const Center(child: Text('Не удалось загрузить курсы'))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      _buildConverter(context, isDark),
                      const SizedBox(height: 20),
                      if (_service.lastFetch != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'Обновлено: ${DateFormat('dd.MM.yyyy HH:mm').format(_service.lastFetch!)}',
                            style: TextStyle(
                              fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ..._rates.map((r) => _RateCard(
                        rate: r,
                        isDark: isDark,
                        displayCurrency: displayCurrency,
                        baseCurrency: _baseCurrency,
                        bankName: _bankNames[r.currency] ?? '',
                        isBankSupported: _bankSupported.contains(r.currency),
                      )),
                    ],
                  ),
      ),
    );
  }

  Widget _buildConverter(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
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
                child: TextField(
                  controller: _convertAmountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(isDense: true, hintText: 'Сумма'),
                  onChanged: (_) => _calculateConversion(),
                ),
              ),
              const SizedBox(width: 8),
              _currencyDropdown(_convertFrom, (v) { if (v != null) setState(() { _convertFrom = v; _calculateConversion(); }); }),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward, size: 16),
              ),
              _currencyDropdown(_convertTo, (v) { if (v != null) setState(() { _convertTo = v; _calculateConversion(); }); }),
            ],
          ),
          if (_convertResult > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_convertAmountCtrl.text} ${
                  CurrencyService.getFlag(_convertFrom)
                } $_convertFrom = ${NumberFormat.currency(symbol: '', decimalDigits: 2).format(_convertResult)} ${
                  CurrencyService.getFlag(_convertTo)
                } $_convertTo',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _currencyDropdown(String value, void Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          items: CurrencyService.supportedCurrencies.map((c) =>
            DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          ).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  final CurrencyRate rate;
  final bool isDark;
  final String displayCurrency;
  final String baseCurrency;
  final String bankName;
  final bool isBankSupported;

  const _RateCard({
    required this.rate,
    required this.isDark,
    required this.displayCurrency,
    required this.baseCurrency,
    required this.bankName,
    required this.isBankSupported,
  });

  @override
  Widget build(BuildContext context) {
    final flag = CurrencyService.getFlag(rate.currency);
    final isDisplay = rate.currency == displayCurrency;
    final bankBuy = rate.rate * 0.98;
    final bankSell = rate.rate * 1.02;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDisplay
            ? AppColors.primary.withValues(alpha: 0.08)
            : (isDark ? AppColors.darkCard : AppColors.cardBackground),
        borderRadius: BorderRadius.circular(16),
        border: isDisplay
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(flag, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          rate.currency,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        if (isDisplay) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'отображение',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bankName.isNotEmpty ? bankName : _nameFor(rate.currency),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormat.currency(symbol: '', decimalDigits: 4).format(rate.rate),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  Text(
                    'за 1 $baseCurrency',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isBankSupported) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _bankRateChip('Покупка', bankBuy, AppColors.success),
                const SizedBox(width: 8),
                _bankRateChip('Продажа', bankSell, AppColors.expense),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bankRateChip(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            Text(
              NumberFormat.currency(symbol: '', decimalDigits: 4).format(value),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }

  String _nameFor(String code) {
    const names = {
      'RUB': 'Российский рубль', 'USD': 'Доллар США', 'EUR': 'Евро',
      'GBP': 'Фунт стерлингов', 'CNY': 'Китайский юань', 'JPY': 'Японская иена',
      'CHF': 'Швейцарский франк', 'KZT': 'Казахстанский тенге',
      'BYN': 'Белорусский рубль', 'AMD': 'Армянский драм',
    };
    return names[code] ?? code;
  }
}
