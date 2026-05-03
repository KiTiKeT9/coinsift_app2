import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/theme_service.dart';

class UserProfileProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final ThemeService _themeService = ThemeService();
  final _uuid = const Uuid();

  UserProfile? _profile;
  bool _isLoading = false;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isDarkTheme => _profile?.darkTheme ?? false;
  bool get enablePinLock => _profile?.enablePinLock ?? false;
  bool get useCustomBackground => _profile?.useCustomBackground ?? false;
  String? get customBackgroundPath => _profile?.customBackgroundPath;

  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    _profile = _db.userProfile;

    if (_profile == null) {
      await createDefaultProfile();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> createDefaultProfile() async {
    _profile = UserProfile(
      id: _uuid.v4(),
      name: 'Пользователь',
      email: '',
      currency: 'RUB',
      monthlyBudget: 50000,
      darkTheme: false,
      language: 'ru',
      enablePinLock: false,
      useCustomBackground: false,
    );
    await _db.saveUserProfile(_profile!);
    notifyListeners();
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    DateTime? birthDate,
    String? avatarPath,
    String? currency,
    double? monthlyBudget,
    bool? darkTheme,
    String? language,
    bool? enablePinLock,
    String? customBackgroundPath,
    bool? useCustomBackground,
  }) async {
    if (_profile == null) return;

    _profile = UserProfile(
      id: _profile!.id,
      name: name ?? _profile!.name,
      email: email ?? _profile!.email,
      birthDate: birthDate ?? _profile!.birthDate,
      avatarPath: avatarPath ?? _profile!.avatarPath,
      currency: currency ?? _profile!.currency,
      monthlyBudget: monthlyBudget ?? _profile!.monthlyBudget,
      notificationSettings: _profile!.notificationSettings,
      darkTheme: darkTheme ?? _profile!.darkTheme,
      language: language ?? _profile!.language,
      enablePinLock: enablePinLock ?? _profile!.enablePinLock,
      customBackgroundPath: customBackgroundPath ?? _profile!.customBackgroundPath,
      useCustomBackground: useCustomBackground ?? _profile!.useCustomBackground,
    );

    await _db.saveUserProfile(_profile!);

    if (useCustomBackground != null || customBackgroundPath != null) {
      await _themeService.setUseCustomBackground(_profile!.useCustomBackground);
      await _themeService.setCustomBackground(_profile!.customBackgroundPath);
    }

    notifyListeners();
  }

  Future<void> toggleDarkTheme() async {
    await updateProfile(darkTheme: !(_profile?.darkTheme ?? false));
  }

  Future<void> togglePinLock() async {
    await updateProfile(enablePinLock: !(_profile?.enablePinLock ?? false));
  }

  Future<void> setMonthlyBudget(double budget) async {
    await updateProfile(monthlyBudget: budget);
  }

  Future<void> setAvatar(String path) async {
    await updateProfile(avatarPath: path);
  }

  Future<void> setCustomBackground(String? path) async {
    await updateProfile(customBackgroundPath: path);
  }

  Future<void> toggleCustomBackground() async {
    await updateProfile(useCustomBackground: !(_profile?.useCustomBackground ?? false));
  }
}
