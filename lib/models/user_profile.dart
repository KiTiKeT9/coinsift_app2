import 'package:hive/hive.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 2)
class UserProfile extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String email;

  @HiveField(3)
  DateTime? birthDate;

  @HiveField(4)
  String? avatarPath;

  @HiveField(5)
  String currency;

  @HiveField(6)
  double monthlyBudget;

  @HiveField(7)
  List<String> notificationSettings;

  @HiveField(8)
  bool darkTheme;

  @HiveField(9)
  String language;

  @HiveField(10)
  bool enablePinLock;

  @HiveField(11)
  String? customBackgroundPath;

  @HiveField(12)
  bool useCustomBackground;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.birthDate,
    this.avatarPath,
    this.currency = 'RUB',
    this.monthlyBudget = 0,
    this.notificationSettings = const [],
    this.darkTheme = false,
    this.language = 'ru',
    this.enablePinLock = false,
    this.customBackgroundPath,
    this.useCustomBackground = false,
  });
}
