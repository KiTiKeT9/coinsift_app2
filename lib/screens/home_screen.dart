import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../providers/accounts_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/user_profile_provider.dart';
import '../utils/app_colors.dart';
import '../utils/app_utils.dart';
import 'package:intl/intl.dart';
import '../widgets/expense_pie_chart.dart';
import '../widgets/skeletons.dart';
import '../widgets/stats_cards.dart';
import '../widgets/transaction_list.dart';
import 'add_transaction_screen.dart';
import 'accounts_screen.dart';
import 'calculators_screen.dart';
import 'investments_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeTab(),
    const AccountsScreen(),
    const CalculatorsScreen(),
    const InvestmentsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final accountsProvider = context.read<AccountsProvider>();
    final transactionsProvider = context.read<TransactionsProvider>();
    final profileProvider = context.read<UserProfileProvider>();

    await Future.wait([
      accountsProvider.loadAccounts(),
      transactionsProvider.loadTransactions(),
      profileProvider.loadProfile(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: _GlassNavBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      ),
      floatingActionButton: _selectedIndex == 0
          ? ZoomIn(
              child: FloatingActionButton.extended(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddTransactionScreen(),
                    ),
                  );
                  if (!context.mounted) return;
                  context.read<AccountsProvider>().loadAccounts();
                  context.read<TransactionsProvider>().loadTransactions();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Добавить'),
              ),
            )
          : null,
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkSurface : Colors.white)
                .withValues(alpha: isDark ? 0.75 : 0.82),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.5),
                width: 1,
              ),
            ),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Главная',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_outlined),
                selectedIcon: Icon(Icons.account_balance_rounded),
                label: 'Счета',
              ),
              NavigationDestination(
                icon: Icon(Icons.calculate_outlined),
                selectedIcon: Icon(Icons.calculate_rounded),
                label: 'Расчеты',
              ),
              NavigationDestination(
                icon: Icon(Icons.trending_up_outlined),
                selectedIcon: Icon(Icons.trending_up_rounded),
                label: 'Инвест',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Профиль',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Timer? _greetingTimer;

  @override
  void initState() {
    super.initState();
    // Перерисовываем приветствие каждую минуту, чтобы оно обновлялось
    // при пересечении границы утро/день/вечер/ночь без рестарта.
    _greetingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _greetingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<UserProfileProvider>();
    final userName = profileProvider.profile?.name;
    final greeting = AppUtils.getPersonalizedGreeting(userName);

    return RefreshIndicator(
      onRefresh: () async {
        final accounts = context.read<AccountsProvider>();
        final transactions = context.read<TransactionsProvider>();
        await Future.wait([
          accounts.loadAccounts(),
          transactions.loadTransactions(),
        ]);
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              expandedTitleScale: 1.25,
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                greeting,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {},
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_outlined, color: AppColors.primary, size: 22),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FadeInDown(
                    from: 20,
                    duration: const Duration(milliseconds: 600),
                    child: _buildTotalBalanceCard(context),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    duration: const Duration(milliseconds: 600),
                    child: _buildStatsCards(context),
                  ),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader(context, 'Аналитика', () {}),
                FadeInUp(
                  delay: const Duration(milliseconds: 400),
                  duration: const Duration(milliseconds: 600),
                  child: const _ChartSection(),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader(context, 'Последние операции', () {}),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FadeInUp(
                    delay: const Duration(milliseconds: 600),
                    duration: const Duration(milliseconds: 600),
                    child: const TransactionList(limit: 5),
                  ),
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
          TextButton(
            onPressed: onTap,
            child: const Text('См. все'),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalBalanceCard(BuildContext context) {
    return Consumer<AccountsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.accounts.isEmpty) {
          return const BalanceCardSkeleton();
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Общий баланс',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Icon(Icons.show_chart_rounded, color: Colors.white38),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppUtils.formatCurrency(provider.totalBalance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildBalanceIndicator(Icons.account_balance_wallet_rounded, 'Счета', '${provider.activeAccounts.length}'),
                  const SizedBox(width: 32),
                  _buildBalanceIndicator(
                    Icons.calendar_today_rounded,
                    'Период',
                    toBeginningOfSentenceCase(
                          DateFormat.yMMMM('ru_RU').format(DateTime.now()),
                        ) ??
                        DateFormat.yMMMM('ru_RU').format(DateTime.now()),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceIndicator(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w500),
            ),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsCards(BuildContext context) {
    return Consumer<TransactionsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.totalIncome == 0 && provider.totalExpenses == 0) {
          return const StatsCardsSkeleton();
        }
        return Row(
          children: [
            Expanded(
              child: StatsCard(
                title: 'Доходы',
                amount: provider.totalIncome,
                icon: Icons.arrow_downward_rounded,
                color: AppColors.income,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatsCard(
                title: 'Расходы',
                amount: provider.totalExpenses,
                icon: Icons.arrow_upward_rounded,
                color: AppColors.expense,
              ),
            ),
          ],
        );
      },
    );
  }

}

class _ChartSection extends StatefulWidget {
  const _ChartSection();

  @override
  State<_ChartSection> createState() => _ChartSectionState();
}

class _ChartSectionState extends State<_ChartSection> {
  bool _showIncome = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionsProvider>(
      builder: (context, provider, _) {
        final hasExpenses = provider.expensesByCategory.isNotEmpty;
        final hasIncome = provider.incomeByCategory.isNotEmpty;
        final hasData = _showIncome ? hasIncome : hasExpenses;

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: isDark ? 0.06 : 0.04),
            ),
          ),
          child: Column(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Расходы'),
                    icon: Icon(Icons.arrow_upward_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Доходы'),
                    icon: Icon(Icons.arrow_downward_rounded, size: 16),
                  ),
                ],
                selected: {_showIncome},
                onSelectionChanged: (s) =>
                    setState(() => _showIncome = s.first),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: hasData
                    ? ExpensePieChart(showIncome: _showIncome)
                    : Center(
                        child: Text(
                          _showIncome
                              ? 'Нет доходов для анализа'
                              : 'Нет расходов для анализа',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                        ),
                      ),
              ),
              if (hasData) ...[
                const SizedBox(height: 16),
                _CategoryLegend(showIncome: _showIncome),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend({required this.showIncome});
  final bool showIncome;

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionsProvider>(
      builder: (context, provider, _) {
        final data = showIncome
            ? provider.incomeByCategory
            : provider.expensesByCategory;
        if (data.isEmpty) return const SizedBox.shrink();
        return ExpenseLegend(data: data);
      },
    );
  }
}
