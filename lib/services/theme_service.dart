import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _customBackgroundKey = 'custom_background_path';
  static const String _useCustomBackgroundKey = 'use_custom_background';

  Future<String?> getCustomBackground() async {
    return await _secureStorage.read(key: _customBackgroundKey);
  }

  Future<void> setCustomBackground(String? path) async {
    if (path == null) {
      await _secureStorage.delete(key: _customBackgroundKey);
    } else {
      await _secureStorage.write(key: _customBackgroundKey, value: path);
    }
  }

  Future<bool> shouldUseCustomBackground() async {
    final value = await _secureStorage.read(key: _useCustomBackgroundKey);
    return value == 'true';
  }

  Future<void> setUseCustomBackground(bool use) async {
    await _secureStorage.write(
      key: _useCustomBackgroundKey,
      value: use.toString(),
    );
  }

  Future<void> clearCustomBackground() async {
    await _secureStorage.delete(key: _customBackgroundKey);
    await _secureStorage.delete(key: _useCustomBackgroundKey);
  }
}
