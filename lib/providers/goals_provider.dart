import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/goal.dart';

class GoalsProvider with ChangeNotifier {
  final _uuid = const Uuid();
  static const String _boxName = 'goals';

  List<Goal> _goals = [];
  bool _isLoading = false;

  List<Goal> get goals => _goals;
  List<Goal> get activeGoals => _goals.where((g) => !g.isCompleted).toList();
  List<Goal> get completedGoals => _goals.where((g) => g.isCompleted).toList();
  bool get isLoading => _isLoading;

  Future<void> loadGoals() async {
    _isLoading = true;
    notifyListeners();

    try {
      final box = await Hive.openBox<Goal>(_boxName);
      _goals = box.values.toList();
    } catch (e) {
      debugPrint('GoalsProvider load error: $e');
      _goals = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addGoal({
    required String title,
    String? description,
    required double targetAmount,
    String currency = 'RUB',
    DateTime? deadline,
    String iconEmoji = '🎯',
    String? category,
    List<GoalStage> stages = const [],
  }) async {
    final goal = Goal(
      id: _uuid.v4(),
      title: title,
      description: description,
      targetAmount: targetAmount,
      currency: currency,
      createdAt: DateTime.now(),
      deadline: deadline,
      iconEmoji: iconEmoji,
      category: category,
      stages: stages,
    );

    final box = await Hive.openBox<Goal>(_boxName);
    await box.put(goal.id, goal);
    await loadGoals();
  }

  Future<void> updateGoal(Goal goal) async {
    final box = await Hive.openBox<Goal>(_boxName);
    await box.put(goal.id, goal);
    await loadGoals();
  }

  Future<void> deleteGoal(String id) async {
    final box = await Hive.openBox<Goal>(_boxName);
    await box.delete(id);
    await loadGoals();
  }

  Future<void> addContribution(String goalId, double amount) async {
    final box = await Hive.openBox<Goal>(_boxName);
    final goal = box.get(goalId);
    if (goal == null) return;

    final newAmount = goal.currentAmount + amount;
    final isCompleted = newAmount >= goal.targetAmount;
    final stages = goal.stages.map((s) => GoalStage(
      id: s.id,
      title: s.title,
      description: s.description,
      targetAmount: s.targetAmount,
      currentAmount: isCompleted ? s.targetAmount : s.currentAmount,
      isCompleted: isCompleted || s.isCompleted,
      sortOrder: s.sortOrder,
    )).toList();

    final updated = Goal(
      id: goal.id,
      title: goal.title,
      description: goal.description,
      targetAmount: goal.targetAmount,
      currentAmount: newAmount,
      currency: goal.currency,
      createdAt: goal.createdAt,
      deadline: goal.deadline,
      iconEmoji: goal.iconEmoji,
      category: goal.category,
      stages: stages,
      notes: goal.notes,
      isCompleted: isCompleted,
    );

    if (!isCompleted) _updateStagesProgress(updated);

    await box.put(goalId, updated);
    await loadGoals();
  }

  Future<void> withdrawContribution(String goalId, double amount) async {
    final box = await Hive.openBox<Goal>(_boxName);
    final goal = box.get(goalId);
    if (goal == null) return;

    final newAmount = (goal.currentAmount - amount).clamp(0, double.infinity).toDouble();
    final updated = Goal(
      id: goal.id,
      title: goal.title,
      description: goal.description,
      targetAmount: goal.targetAmount,
      currentAmount: newAmount,
      currency: goal.currency,
      createdAt: goal.createdAt,
      deadline: goal.deadline,
      iconEmoji: goal.iconEmoji,
      category: goal.category,
      stages: goal.stages.map((s) => GoalStage(
        id: s.id,
        title: s.title,
        description: s.description,
        targetAmount: s.targetAmount,
        currentAmount: s.currentAmount,
        isCompleted: false,
        sortOrder: s.sortOrder,
      )).toList(),
      notes: goal.notes,
      isCompleted: false,
    );

    _updateStagesProgress(updated);
    await box.put(goalId, updated);
    await loadGoals();
  }

  Future<void> addStage(String goalId, GoalStage stage) async {
    final box = await Hive.openBox<Goal>(_boxName);
    final goal = box.get(goalId);
    if (goal == null) return;

    final updated = Goal(
      id: goal.id,
      title: goal.title,
      description: goal.description,
      targetAmount: goal.targetAmount,
      currentAmount: goal.currentAmount,
      currency: goal.currency,
      createdAt: goal.createdAt,
      deadline: goal.deadline,
      iconEmoji: goal.iconEmoji,
      category: goal.category,
      stages: [...goal.stages, stage],
      notes: goal.notes,
      isCompleted: goal.isCompleted,
    );
    await box.put(goalId, updated);
    await loadGoals();
  }

  Future<void> updateStage(String goalId, GoalStage stage) async {
    final box = await Hive.openBox<Goal>(_boxName);
    final goal = box.get(goalId);
    if (goal == null) return;

    final updatedStages = goal.stages.map((s) => s.id == stage.id ? stage : s).toList();
    final updated = Goal(
      id: goal.id,
      title: goal.title,
      description: goal.description,
      targetAmount: goal.targetAmount,
      currentAmount: goal.currentAmount,
      currency: goal.currency,
      createdAt: goal.createdAt,
      deadline: goal.deadline,
      iconEmoji: goal.iconEmoji,
      category: goal.category,
      stages: updatedStages,
      notes: goal.notes,
      isCompleted: goal.isCompleted,
    );
    _updateStagesProgress(updated);
    await box.put(goalId, updated);
    await loadGoals();
  }

  Future<void> addNote(String goalId, String text) async {
    final box = await Hive.openBox<Goal>(_boxName);
    final goal = box.get(goalId);
    if (goal == null) return;

    final updated = Goal(
      id: goal.id,
      title: goal.title,
      description: goal.description,
      targetAmount: goal.targetAmount,
      currentAmount: goal.currentAmount,
      currency: goal.currency,
      createdAt: goal.createdAt,
      deadline: goal.deadline,
      iconEmoji: goal.iconEmoji,
      category: goal.category,
      stages: goal.stages,
      notes: [...goal.notes, GoalNote(
        id: _uuid.v4(),
        text: text,
        createdAt: DateTime.now(),
      )],
      isCompleted: goal.isCompleted,
    );
    await box.put(goalId, updated);
    await loadGoals();
  }

  Future<void> deleteNote(String goalId, String noteId) async {
    final box = await Hive.openBox<Goal>(_boxName);
    final goal = box.get(goalId);
    if (goal == null) return;

    final updated = Goal(
      id: goal.id,
      title: goal.title,
      description: goal.description,
      targetAmount: goal.targetAmount,
      currentAmount: goal.currentAmount,
      currency: goal.currency,
      createdAt: goal.createdAt,
      deadline: goal.deadline,
      iconEmoji: goal.iconEmoji,
      category: goal.category,
      stages: goal.stages,
      notes: goal.notes.where((n) => n.id != noteId).toList(),
      isCompleted: goal.isCompleted,
    );
    await box.put(goalId, updated);
    await loadGoals();
  }

  void _updateStagesProgress(Goal goal) {
    double totalTarget = goal.stages.fold(0, (sum, s) => sum + s.targetAmount);
    if (totalTarget <= 0) return;

    for (final stage in goal.stages) {
      if (stage.isCompleted) continue;
      stage.currentAmount = (goal.currentAmount / totalTarget) * stage.targetAmount;
      if (stage.currentAmount >= stage.targetAmount) {
        stage.isCompleted = true;
        stage.currentAmount = stage.targetAmount;
      }
    }
  }

  Goal? getGoalById(String id) {
    final matches = _goals.where((g) => g.id == id).toList();
    return matches.isEmpty ? null : matches.first;
  }
}
