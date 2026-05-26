import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'models/account.dart';
import 'models/transaction.dart';
import 'models/user_profile.dart';
import 'models/investment.dart';
import 'models/calculator_record.dart';
import 'models/currency_rate.dart';
import 'models/goal.dart';

import 'providers/accounts_provider.dart';
import 'providers/goals_provider.dart';
import 'providers/bank_signals_controller.dart';
import 'providers/investments_provider.dart';
import 'providers/transactions_provider.dart';
import 'providers/user_profile_provider.dart';

import 'services/currency_service.dart';
import 'services/database_service.dart';
import 'services/logo_cache_service.dart';
import 'services/security_service.dart';

import 'screens/home_screen.dart';
import 'screens/bank_aggregator_screen.dart';
import 'screens/bank_import_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'utils/app_colors.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ru_RU', null);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  try {
    await _initStorage();
  } catch (e) {
    debugPrint('Error during initialization: $e');
    await _clearHiveBoxes();
    await _initStorage();
  }

  runApp(const MonetkaApp());
}

Future<void> _initStorage() async {
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(AccountAdapter().typeId)) {
    Hive.registerAdapter(AccountAdapter());
  }
  if (!Hive.isAdapterRegistered(TransactionAdapter().typeId)) {
    Hive.registerAdapter(TransactionAdapter());
  }
  if (!Hive.isAdapterRegistered(UserProfileAdapter().typeId)) {
    Hive.registerAdapter(UserProfileAdapter());
  }
  if (!Hive.isAdapterRegistered(InvestmentAdapter().typeId)) {
    Hive.registerAdapter(InvestmentAdapter());
  }
  if (!Hive.isAdapterRegistered(CalculatorRecordAdapter().typeId)) {
    Hive.registerAdapter(CalculatorRecordAdapter());
  }
  if (!Hive.isAdapterRegistered(CurrencyRateAdapter().typeId)) {
    Hive.registerAdapter(CurrencyRateAdapter());
  }
  if (!Hive.isAdapterRegistered(GoalAdapter().typeId)) {
    Hive.registerAdapter(GoalAdapter());
  }
  if (!Hive.isAdapterRegistered(GoalStageAdapter().typeId)) {
    Hive.registerAdapter(GoalStageAdapter());
  }
  if (!Hive.isAdapterRegistered(GoalNoteAdapter().typeId)) {
    Hive.registerAdapter(GoalNoteAdapter());
  }

  await SecurityService().init();
  await DatabaseService().init();
  await LogoCacheService.instance.init();
}

Future<void> _clearHiveBoxes() async {
  try {
    await Hive.deleteBoxFromDisk('accounts');
    await Hive.deleteBoxFromDisk('transactions');
    await Hive.deleteBoxFromDisk('user_profile');
    await Hive.deleteBoxFromDisk('investments');
    await Hive.deleteBoxFromDisk('calculators');
  } catch (e) {
    debugPrint('Error clearing boxes: $e');
  }
}

class MonetkaApp extends StatelessWidget {
  const MonetkaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccountsProvider()),
        ChangeNotifierProvider(create: (_) => TransactionsProvider()),
        ChangeNotifierProvider(create: (_) => InvestmentsProvider()),
        ChangeNotifierProvider(create: (_) => GoalsProvider()),
        // Профиль грузим сразу при создании, чтобы тема (light/dark)
        // применялась с первого кадра, ещё до Splash.
        ChangeNotifierProvider(
          create: (_) => UserProfileProvider()..loadProfile(),
        ),
        // Банковские сигналы (SMS + push) — зависят от TransactionsProvider
        // для вызова bulkImport, поэтому через ProxyProvider.
        ChangeNotifierProxyProvider<TransactionsProvider, BankSignalsController>(
          create: (context) => BankSignalsController(
            context.read<TransactionsProvider>(),
          ),
          update: (_, txs, prev) =>
              (prev ?? BankSignalsController(txs))..updateTransactions(txs),
        ),
      ],
      child: DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          return Consumer<UserProfileProvider>(
            builder: (context, profileProvider, _) {
              final useDynamic = profileProvider.useDynamicColor;
              return MaterialApp(
                title: 'Монетка',
                debugShowCheckedModeBanner: false,
                locale: const Locale('ru', 'RU'),
                supportedLocales: const [
                  Locale('ru', 'RU'),
                  Locale('en', 'US'),
                ],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: AppTheme.lightTheme(
                  dynamicColorScheme: useDynamic ? lightDynamic : null,
                ),
                darkTheme: AppTheme.darkTheme(
                  dynamicColorScheme: useDynamic ? darkDynamic : null,
                ),
                themeMode: profileProvider.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
                navigatorKey: navigatorKey,
                home: const SplashScreen(),
                routes: {
                  '/bank-aggregator': (context) => const BankAggregatorScreen(),
                  '/bank-import': (context) => const BankImportScreen(),
                },
              );
            },
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final profileProvider = context.read<UserProfileProvider>();
      final accountsProvider = context.read<AccountsProvider>();
      final transactionsProvider = context.read<TransactionsProvider>();
      final investmentsProvider = context.read<InvestmentsProvider>();
      final goalsProvider = context.read<GoalsProvider>();

      await Future.wait([
        profileProvider.loadProfile(),
        accountsProvider.loadAccounts(),
        transactionsProvider.loadTransactions(),
        investmentsProvider.loadInvestments(),
        goalsProvider.loadGoals(),
        CurrencyService().fetchRates(),
      ]);

      // Автостарт SMS/push-листенеров, если пользователь их включал.
      if (mounted) {
        unawaited(
          context.read<BankSignalsController>().autoStart(),
        );
      }

      await Future.delayed(const Duration(milliseconds: 1000));

      if (mounted) {
        final enablePinLock = profileProvider.enablePinLock;

        if (enablePinLock) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => PinLockScreen(
                onSuccess: () {
                  navigatorKey.currentState?.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                  );
                },
              ),
              transitionsBuilder: (_, a, __, c) => FadeTransition(
                opacity: a,
                child: c,
              ),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const HomeScreen(),
              transitionsBuilder: (_, a, __, c) => FadeTransition(
                opacity: a,
                child: c,
              ),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error during app initialization: $e');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<UserProfileProvider>();
    final useCustomBg = profileProvider.useCustomBackground;
    final bgPath = profileProvider.customBackgroundPath;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (useCustomBg && bgPath != null && File(bgPath).existsSync())
            Image.file(
              File(bgPath),
              fit: BoxFit.cover,
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
            ),

          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance,
                        size: 80,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Монетка',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Управляйте деньгами легко',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 48),
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
