import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/transactions_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';

class ExpensePieChart extends StatelessWidget {
  final bool showIncome;

  const ExpensePieChart({
    super.key,
    this.showIncome = false,
  });

  @override
  Widget build(BuildContext context) {
    final transactionsProvider = context.watch<TransactionsProvider>();
    final data = showIncome
        ? transactionsProvider.incomeByCategory
        : transactionsProvider.expensesByCategory;

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 60,
              color: AppColors.textLight.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              showIncome ? 'Нет доходов' : 'Нет расходов',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final total = data.values.fold<double>(0, (sum, value) => sum + value);
    final sections = _generateSections(data, total);

    return PieChart(
      PieChartData(
        sections: sections,
        sectionsSpace: 4,
        centerSpaceRadius: 35,
        startDegreeOffset: -90,
        pieTouchData: PieTouchData(
          enabled: true,
        ),
      ),
    );
  }

  List<PieChartSectionData> _generateSections(
      Map<String, double> data, double total) {
    final sections = <PieChartSectionData>[];

    data.forEach((category, value) {
      final percentage = (value / total) * 100;
      final catInfo = TransactionCategories.getCategoryByName(category);
      final color = Color(int.parse((catInfo['color'] ?? '#94A3B8').replaceFirst('#', 'FF'), radix: 16));

      sections.add(
        PieChartSectionData(
          value: value,
          title: percentage > 10 ? '${percentage.toStringAsFixed(0)}%' : '',
          color: color,
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });

    return sections;
  }
}
