import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/investment.dart';
import '../services/database_service.dart';
import '../services/investment_api_service.dart';

class InvestmentsProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final _uuid = const Uuid();

  List<Investment> _investments = [];
  bool _isLoading = false;
  bool _isUpdatingPrices = false;
  String? _lastUpdateError;

  List<Investment> get investments => _investments;
  bool get isLoading => _isLoading;
  bool get isUpdatingPrices => _isUpdatingPrices;
  String? get lastUpdateError => _lastUpdateError;

  double get totalValue {
    return _investments.fold(0, (sum, inv) => sum + inv.totalValue);
  }

  double get totalCost {
    return _investments.fold(0, (sum, inv) => sum + inv.totalCost);
  }

  double get totalProfitLoss {
    return totalValue - totalCost;
  }

  double get totalProfitLossPercent {
    return totalCost != 0 ? (totalProfitLoss / totalCost) * 100 : 0;
  }

  Map<String, double> get allocationByType {
    final Map<String, double> typeMap = {};
    for (var investment in _investments) {
      typeMap[investment.type] = (typeMap[investment.type] ?? 0) + investment.totalValue;
    }
    return typeMap;
  }

  Map<String, double> get allocationBySector {
    final Map<String, double> sectorMap = {};
    for (var investment in _investments) {
      sectorMap[investment.sector] = (sectorMap[investment.sector] ?? 0) + investment.totalValue;
    }
    return sectorMap;
  }

  List<Investment> get getStocks =>
      _investments.where((i) => i.type == 'stock').toList();

  List<Investment> get getBonds =>
      _investments.where((i) => i.type == 'bond').toList();

  List<Investment> get getETFs =>
      _investments.where((i) => i.type == 'etf').toList();

  List<Investment> get getFunds =>
      _investments.where((i) => i.type == 'fund').toList();

  List<Investment> get getTopGainers {
    final sorted = List<Investment>.from(_investments)
      ..sort((a, b) => b.profitLossPercent.compareTo(a.profitLossPercent));
    return sorted;
  }

  List<Investment> get getTopLosers {
    final sorted = List<Investment>.from(_investments)
      ..sort((a, b) => a.profitLossPercent.compareTo(b.profitLossPercent));
    return sorted;
  }

  Future<void> loadInvestments() async {
    _isLoading = true;
    notifyListeners();

    _investments = _db.allInvestments;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addInvestment({
    required String name,
    required String ticker,
    required String type,
    required int quantity,
    required double averagePrice,
    required double currentPrice,
    String currency = 'RUB',
    String? exchange,
    String sector = '',
  }) async {
    final investment = Investment(
      id: _uuid.v4(),
      name: name,
      ticker: ticker,
      type: type,
      quantity: quantity,
      averagePrice: averagePrice,
      currentPrice: currentPrice,
      currency: currency,
      purchaseDate: DateTime.now(),
      exchange: exchange,
      sector: sector,
    );

    await _db.addInvestment(investment);
    await loadInvestments();
  }

  Future<void> updateInvestment(Investment investment) async {
    await _db.updateInvestment(investment);
    await loadInvestments();
  }

  Future<void> updatePrice(String id, double newPrice) async {
    final index = _investments.indexWhere((i) => i.id == id);
    if (index != -1) {
      _investments[index].currentPrice = newPrice;
      await _db.updateInvestment(_investments[index]);
      notifyListeners();
    }
  }

  Future<void> deleteInvestment(String id) async {
    await _db.deleteInvestment(id);
    await loadInvestments();
  }

  Investment? getInvestmentById(String id) {
    try {
      return _investments.firstWhere((i) => i.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Обновление цен с использованием реальных данных из API
  Future<void> updatePrices() async {
    if (_investments.isEmpty) return;

    _isUpdatingPrices = true;
    _lastUpdateError = null;
    notifyListeners();

    try {
      int updatedCount = 0;
      int failedCount = 0;

      for (var investment in _investments) {
        try {
          double? newPrice;

          // Определяем, какой API использовать
          if (InvestmentApiService.isRussianTicker(investment.ticker)) {
            // Для российских акций используем MOEX
            newPrice = await InvestmentApiService.getMoexPrice(investment.ticker);
          } else {
            // Для зарубежных акций можно использовать другие API
            // Пока оставляем заглушку или используем текущую цену
            newPrice = null;
          }

          if (newPrice != null && newPrice > 0) {
            investment.currentPrice = newPrice;
            await _db.updateInvestment(investment);
            updatedCount++;
          } else {
            failedCount++;
          }
        } catch (e) {
          failedCount++;
          debugPrint('Ошибка обновления цены для ${investment.ticker}: $e');
        }
      }

      _lastUpdateError = failedCount > 0
          ? 'Обновлено: $updatedCount, ошибок: $failedCount'
          : null;

      _isUpdatingPrices = false;
      notifyListeners();
    } catch (e) {
      _lastUpdateError = 'Ошибка обновления цен: $e';
      _isUpdatingPrices = false;
      notifyListeners();
    }
  }
}
