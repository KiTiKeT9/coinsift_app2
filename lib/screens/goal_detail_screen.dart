import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/goals_provider.dart';
import '../models/goal.dart';
import '../utils/app_colors.dart';
import '../utils/app_utils.dart';

class GoalDetailScreen extends StatefulWidget {
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final goal = context.read<GoalsProvider>().getGoalById(widget.goalId);
      if (goal != null && !_animController.isCompleted) {
        _animController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GoalsProvider>(
      builder: (context, provider, _) {
        final goal = provider.getGoalById(widget.goalId);
        if (goal == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Цель')),
            body: const Center(child: Text('Цель не найдена')),
          );
        }

        final progress = goal.progressPercent;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(
            title: Text(goal.title),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') {
                    _confirmDelete(context, provider, goal);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Удалить цель', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressCard(context, goal, progress, isDark),
                const SizedBox(height: 24),
                _buildQuickActions(context, provider, goal),
                const SizedBox(height: 24),
                _buildStagesSection(context, provider, goal, isDark),
                const SizedBox(height: 24),
                _buildNotesSection(context, provider, goal, isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressCard(BuildContext context, Goal goal, double progress, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: goal.isCompleted
              ? [AppColors.success, AppColors.success.withValues(alpha: 0.8)]
              : [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (goal.isCompleted ? AppColors.success : AppColors.primary).withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                goal.iconEmoji ?? '🎯',
                style: const TextStyle(fontSize: 36),
              ),
              if (goal.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Выполнено!',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress * _progressAnimation.value,
                minHeight: 14,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    goal.isCompleted
                        ? 'Цель достигнута!'
                        : 'из ${AppUtils.formatCurrency(goal.targetAmount, currency: goal.currency)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppUtils.formatCurrency(goal.currentAmount, currency: goal.currency),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'накоплено',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (goal.deadline != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  goal.isOverdue ? 'Просрочено' : 'до ${AppUtils.formatDate(goal.deadline!)}',
                  style: TextStyle(
                    color: goal.isOverdue ? Colors.yellow : Colors.white70,
                    fontSize: 12,
                    fontWeight: goal.isOverdue ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, GoalsProvider provider, Goal goal) {
    final amountCtrl = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Быстрые действия', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Сумма',
                    suffixText: goal.currency,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                    if (amount != null && amount > 0) {
                      provider.addContribution(goal.id, amount);
                      amountCtrl.clear();
                      _animController.reset();
                      _animController.forward();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Добавлено ${AppUtils.formatCurrency(amount, currency: goal.currency)}')),
                      );
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Внести'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                    if (amount != null && amount > 0) {
                      provider.withdrawContribution(goal.id, amount);
                      amountCtrl.clear();
                      _animController.reset();
                      _animController.forward();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Списано ${AppUtils.formatCurrency(amount, currency: goal.currency)}')),
                      );
                    }
                  },
                  icon: const Icon(Icons.remove_rounded, size: 18),
                  label: const Text('Списать'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStagesSection(BuildContext context, GoalsProvider provider, Goal goal, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Этапы', style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showAddStageDialog(context, provider, goal),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Добавить этап'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (goal.stages.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Center(
              child: Text(
                'Нет этапов. Добавьте этапы для декомпозиции цели.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          )
        else
          ...goal.stages.map((stage) => _StageTile(
            stage: stage,
            goal: goal,
            provider: provider,
            isDark: isDark,
          )),
      ],
    );
  }

  Widget _buildNotesSection(BuildContext context, GoalsProvider provider, Goal goal, bool isDark) {
    final noteCtrl = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Заметки', style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: noteCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Написать заметку...',
                  isDense: true,
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) {
                    provider.addNote(goal.id, v.trim());
                    noteCtrl.clear();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () {
                if (noteCtrl.text.trim().isNotEmpty) {
                  provider.addNote(goal.id, noteCtrl.text.trim());
                  noteCtrl.clear();
                }
              },
              icon: const Icon(Icons.send_rounded, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (goal.notes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Пока нет заметок',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          )
        else
          ...goal.notes.reversed.map((note) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.text,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppUtils.formatDateTime(note.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => provider.deleteNote(goal.id, note.id),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close, size: 14, color: AppColors.error),
                  ),
                ),
              ],
            ),
          )),
      ],
    );
  }

  void _showAddStageDialog(BuildContext context, GoalsProvider provider, Goal goal) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Новый этап', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Название этапа',
                      hintText: 'Например: Первый взнос 30%',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Сумма этапа',
                      prefixIcon: Icon(Icons.monetization_on_outlined),
                    ),
                    validator: (v) {
                      final val = double.tryParse(v?.replaceAll(',', '.') ?? '');
                      return (val == null || val <= 0) ? 'Укажите сумму' : null;
                    },
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
                        onPressed: () async {
                          if (!(formKey.currentState?.validate() ?? false)) return;
                          final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'))!;
                          final stage = GoalStage(
                            id: const Uuid().v4(),
                            title: titleCtrl.text.trim(),
                            targetAmount: amount,
                            sortOrder: goal.stages.length,
                          );
                          await provider.addStage(goal.id, stage);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Добавить'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, GoalsProvider provider, Goal goal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить цель?'),
        content: Text('Вы уверены, что хотите удалить цель "${goal.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              provider.deleteGoal(goal.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Удалить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  final GoalStage stage;
  final Goal goal;
  final GoalsProvider provider;
  final bool isDark;

  const _StageTile({
    required this.stage,
    required this.goal,
    required this.provider,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final progress = stage.progressPercent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stage.isCompleted
              ? AppColors.success.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: stage.isCompleted
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: stage.isCompleted
                      ? const Icon(Icons.check, size: 16, color: AppColors.success)
                      : Text(
                          '${stage.sortOrder + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stage.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    decoration: stage.isCompleted ? TextDecoration.lineThrough : null,
                    color: stage.isCompleted
                        ? AppColors.textLight
                        : null,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: stage.isCompleted ? AppColors.success : null,
                ),
              ),
            ],
          ),
          if (stage.description != null && stage.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(
                stage.description!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                valueColor: AlwaysStoppedAnimation<Color>(
                  stage.isCompleted ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${AppUtils.formatCurrency(stage.currentAmount, currency: goal.currency)} / ${AppUtils.formatCurrency(stage.targetAmount, currency: goal.currency)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
