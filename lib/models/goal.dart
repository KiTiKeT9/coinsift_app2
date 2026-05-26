import 'package:hive/hive.dart';

part 'goal.g.dart';

@HiveType(typeId: 6)
class Goal extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  double targetAmount;

  @HiveField(4)
  double currentAmount;

  @HiveField(5)
  String currency;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime? deadline;

  @HiveField(8)
  String? iconEmoji;

  @HiveField(9)
  String? category;

  @HiveField(10)
  List<GoalStage> stages;

  @HiveField(11)
  List<GoalNote> notes;

  @HiveField(12)
  bool isCompleted;

  Goal({
    required this.id,
    required this.title,
    this.description,
    required this.targetAmount,
    this.currentAmount = 0,
    this.currency = 'RUB',
    required this.createdAt,
    this.deadline,
    this.iconEmoji = '🎯',
    this.category,
    List<GoalStage>? stages,
    List<GoalNote>? notes,
    this.isCompleted = false,
  })  : stages = stages ?? [],
        notes = notes ?? [];

  double get progressPercent =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  double get remainingAmount => (targetAmount - currentAmount).clamp(0, double.infinity);

  bool get isOverdue =>
      deadline != null && deadline!.isBefore(DateTime.now()) && !isCompleted;
}

@HiveType(typeId: 7)
class GoalStage {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  double targetAmount;

  @HiveField(4)
  double currentAmount;

  @HiveField(5)
  bool isCompleted;

  @HiveField(6)
  int sortOrder;

  GoalStage({
    required this.id,
    required this.title,
    this.description,
    required this.targetAmount,
    this.currentAmount = 0,
    this.isCompleted = false,
    this.sortOrder = 0,
  });

  double get progressPercent =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
}

@HiveType(typeId: 8)
class GoalNote {
  @HiveField(0)
  String id;

  @HiveField(1)
  String text;

  @HiveField(2)
  DateTime createdAt;

  @HiveField(3)
  DateTime? updatedAt;

  GoalNote({
    required this.id,
    required this.text,
    required this.createdAt,
    this.updatedAt,
  });
}
