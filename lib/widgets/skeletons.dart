import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Переиспользуемые shimmer-скелетоны.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.06),
      highlightColor: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.12),
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }
}

/// Прямоугольный плейсхолдер.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Скелетон для карточки общего баланса.
class BalanceCardSkeleton extends StatelessWidget {
  const BalanceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 120, height: 14),
            SizedBox(height: 12),
            SkeletonBox(width: 220, height: 34, radius: 12),
            SizedBox(height: 24),
            Row(
              children: [
                SkeletonBox(width: 90, height: 32, radius: 12),
                SizedBox(width: 16),
                SkeletonBox(width: 120, height: 32, radius: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Скелетон для пары карточек "Доходы/Расходы".
class StatsCardsSkeleton extends StatelessWidget {
  const StatsCardsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: Row(
        children: [
          Expanded(child: _statCard(context)),
          const SizedBox(width: 16),
          Expanded(child: _statCard(context)),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 42, height: 42, radius: 14),
          SizedBox(height: 16),
          SkeletonBox(width: 70, height: 12),
          SizedBox(height: 6),
          SkeletonBox(width: 120, height: 20, radius: 10),
        ],
      ),
    );
  }
}

/// Скелетон для списка транзакций.
class TransactionListSkeleton extends StatelessWidget {
  const TransactionListSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: Column(
        children: List.generate(itemCount, (_) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  SkeletonBox(width: 52, height: 52, radius: 16),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 140, height: 14),
                        SizedBox(height: 6),
                        SkeletonBox(width: 80, height: 12),
                      ],
                    ),
                  ),
                  SkeletonBox(width: 80, height: 16),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
