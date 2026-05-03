import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/investments_provider.dart';
import '../models/investment.dart';
import '../models/investment_instrument.dart';
import '../services/investment_api_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_utils.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('Инвестиции'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.wallet_rounded), text: 'Портфель'),
            Tab(icon: Icon(Icons.search_rounded), text: 'Каталог'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          PortfolioTab(),
          CatalogTab(),
        ],
      ),
    );
  }
}

class PortfolioTab extends StatelessWidget {
  const PortfolioTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InvestmentsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.investments.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.investments.isEmpty) {
          return _buildEmptyState(context);
        }

        return RefreshIndicator(
          onRefresh: () async {
            await provider.loadInvestments();
            await provider.updatePrices();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildPortfolioSummary(provider),
              const SizedBox(height: 24),
              _buildAllocationChart(provider, context),
              const SizedBox(height: 24),
              _buildHoldingsList(provider, context),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              size: 80,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Портфель пуст',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Выберите активы в каталоге',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioSummary(InvestmentsProvider provider) {
    final profitLoss = provider.totalProfitLoss;
    final isPositive = profitLoss >= 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isPositive 
          ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
          : const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFBE123C)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (isPositive ? AppColors.success : AppColors.error).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Общая стоимость', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(
            AppUtils.formatCurrency(provider.totalValue),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${provider.totalProfitLossPercent.toStringAsFixed(2)}%',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                (isPositive ? '+' : '') + AppUtils.formatCurrency(profitLoss),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _SummaryItem(label: 'Вложено', value: AppUtils.formatCurrency(provider.totalCost))),
              Container(width: 1, height: 30, color: Colors.white24),
              Expanded(child: _SummaryItem(label: 'Активы', value: '${provider.investments.length}')),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildAllocationChart(InvestmentsProvider provider, BuildContext context) {
    final allocation = provider.allocationByType;
    if (allocation.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Распределение', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sections: _generatePieSections(allocation),
                sectionsSpace: 4,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: allocation.entries.map((entry) {
              final index = allocation.keys.toList().indexOf(entry.key);
              final color = AppColors.chartColors[index % AppColors.chartColors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(_getTypeName(entry.key), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  List<PieChartSectionData> _generatePieSections(Map<String, double> allocation) {
    final total = allocation.values.fold<double>(0, (sum, v) => sum + v);
    int index = 0;
    return allocation.entries.map((entry) {
      final percentage = (entry.value / total) * 100;
      final color = AppColors.chartColors[index % AppColors.chartColors.length];
      index++;
      return PieChartSectionData(
        value: entry.value,
        title: percentage > 10 ? '${percentage.toStringAsFixed(0)}%' : '',
        color: color,
        radius: 45,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Widget _buildHoldingsList(InvestmentsProvider provider, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 16),
          child: Text('Мои активы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        ...provider.investments.map((investment) => _InvestmentTile(
          investment: investment,
          onTap: () => _showEditInvestmentDialog(context, investment),
          onDelete: () => provider.deleteInvestment(investment.id),
        )),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  void _showEditInvestmentDialog(BuildContext context, Investment investment) {
    final priceController = TextEditingController(text: investment.currentPrice.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(investment.name),
        content: TextField(
          controller: priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Текущая цена', prefixText: '₽ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(priceController.text) ?? 0;
              context.read<InvestmentsProvider>().updatePrice(investment.id, price);
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}

class CatalogTab extends StatefulWidget {
  const CatalogTab({super.key});

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
  final TextEditingController _searchController = TextEditingController();
  List<InvestmentInstrument> _instruments = [];
  List<InvestmentInstrument> _filteredInstruments = [];
  bool _isLoading = true;
  String _selectedType = 'all';

  @override
  void initState() {
    super.initState();
    _loadInstruments();
    _searchController.addListener(_filterInstruments);
  }

  Future<void> _loadInstruments() async {
    final instruments = await InvestmentApiService.getPopularInstruments();
    if (mounted) {
      setState(() {
        _instruments = instruments;
        _filteredInstruments = instruments;
        _isLoading = false;
      });
    }
  }

  void _filterInstruments() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredInstruments = _instruments.where((i) {
        final matchesQuery = i.name.toLowerCase().contains(query) || i.ticker.toLowerCase().contains(query);
        final matchesType = _selectedType == 'all' || i.type == _selectedType;
        return matchesQuery && matchesType;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Поиск активов...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterChip(label: 'Все', isSelected: _selectedType == 'all', onTap: () { setState(() => _selectedType = 'all'); _filterInstruments(); }),
              _FilterChip(label: 'Акции', isSelected: _selectedType == 'stock', onTap: () { setState(() => _selectedType = 'stock'); _filterInstruments(); }),
              _FilterChip(label: 'Облигации', isSelected: _selectedType == 'bond', onTap: () { setState(() => _selectedType = 'bond'); _filterInstruments(); }),
              _FilterChip(label: 'ETF', isSelected: _selectedType == 'etf', onTap: () { setState(() => _selectedType = 'etf'); _filterInstruments(); }),
            ],
          ),
        ),
        Expanded(
          child: _filteredInstruments.isEmpty 
            ? const Center(child: Text('Ничего не найдено'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredInstruments.length,
                itemBuilder: (context, index) => _InstrumentCard(
                  instrument: _filteredInstruments[index],
                  onAdd: () => _showAddDialog(context, _filteredInstruments[index]),
                ),
              ),
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context, InvestmentInstrument instrument) {
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController(text: instrument.price?.toString() ?? '0');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Добавить ${instrument.ticker}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Количество')),
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Цена покупки', prefixText: '₽ ')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(qtyController.text) ?? 0;
              final price = double.tryParse(priceController.text) ?? 0;
              if (qty > 0 && price > 0) {
                context.read<InvestmentsProvider>().addInvestment(
                  name: instrument.name,
                  ticker: instrument.ticker,
                  type: instrument.type,
                  quantity: qty,
                  averagePrice: price,
                  currentPrice: instrument.price ?? price,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }
}

class _InvestmentTile extends StatelessWidget {
  final Investment investment;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _InvestmentTile({required this.investment, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositive = investment.profitLoss >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        child: Row(
          children: [
            _AssetLogo(
              ticker: investment.ticker,
              fallbackEmoji: investment.ticker.substring(0, 1),
              size: 48,
              radius: 12,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(investment.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${investment.quantity} шт • ₽${investment.currentPrice}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(AppUtils.formatCurrency(investment.totalValue), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(
                  '${isPositive ? '+' : ''}${investment.profitLossPercent.toStringAsFixed(2)}%',
                  style: TextStyle(color: isPositive ? AppColors.success : AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InstrumentCard extends StatelessWidget {
  final InvestmentInstrument instrument;
  final VoidCallback onAdd;
  const _InstrumentCard({required this.instrument, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onAdd,
        leading: _AssetLogo(
          ticker: instrument.ticker,
          fallbackEmoji: instrument.typeEmoji,
        ),
        title: Text(instrument.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(instrument.ticker),
        trailing: Text('₽${instrument.price?.toStringAsFixed(2) ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _AssetLogo extends StatelessWidget {
  const _AssetLogo({
    required this.ticker,
    required this.fallbackEmoji,
    this.size = 40,
    this.radius = 10,
  });

  final String ticker;
  final String fallbackEmoji;
  final double size;
  final double radius;

  // Tinkoff Investments публичный CDN с логотипами эмитентов.
  // Используем 160px вариант — резкий на любых плотностях.
  String get _logoUrl =>
      'https://invest-brands.cdn-tinkoff.ru/${ticker.toUpperCase()}x160.png';

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Text(
          fallbackEmoji,
          style: TextStyle(fontSize: size * 0.45, fontWeight: FontWeight.bold),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        _logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder;
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        labelStyle: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

String _getTypeName(String type) {
  switch (type) {
    case 'stock': return 'Акции';
    case 'bond': return 'Облигации';
    case 'etf': return 'ETF';
    default: return 'Прочее';
  }
}
