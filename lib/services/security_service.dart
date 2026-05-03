import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:crypto/crypto.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _hiveEncryptionKey = 'hive_encryption_key_v1';
  static const String _authToken = 'auth_token';
  static const String _refreshToken = 'refresh_token';
  static const String _userPinHash = 'user_pin_hash';
  static const String _pinFailCount = 'pin_fail_count';
  static const String _pinLockUntil = 'pin_lock_until_ms';

  // Прогрессивные задержки после неверных попыток PIN.
  static const List<Duration> _lockoutSteps = [
    Duration.zero,
    Duration.zero,
    Duration.zero,
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 60),
  ];

  Future<void> init() async {
    await _getOrCreateHiveKey();
  }

  Future<Uint8List> getHiveEncryptionKey() async {
    return base64Decode(await _getOrCreateHiveKey());
  }

  Future<String> _getOrCreateHiveKey() async {
    String? key = await _secureStorage.read(key: _hiveEncryptionKey);

    if (key == null) {
      final random = Random.secure();
      final bytes = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        bytes[i] = random.nextInt(256);
      }
      key = base64Encode(bytes);
      await _secureStorage.write(key: _hiveEncryptionKey, value: key);
    }
    
    return key;
  }

  Future<void> saveAuthToken(String token) async {
    await _secureStorage.write(key: _authToken, value: token);
  }

  Future<String?> getAuthToken() async {
    return await _secureStorage.read(key: _authToken);
  }

  Future<void> deleteAuthToken() async {
    await _secureStorage.delete(key: _authToken);
  }

  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: _refreshToken, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshToken);
  }

  Future<void> deleteUserCredentials() async {
    await _secureStorage.deleteAll();
  }

  String hashPinCode(String pinCode) {
    final bytes = utf8.encode(pinCode);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> hasPinCode() async {
    final storedHash = await _secureStorage.read(key: _userPinHash);
    return storedHash != null;
  }

  Future<bool> verifyPinCode(String pinCode) async {
    if (await remainingLockout() > Duration.zero) return false;

    final storedHash = await _secureStorage.read(key: _userPinHash);
    if (storedHash == null) return false;

    final inputHash = hashPinCode(pinCode);
    final ok = storedHash == inputHash;

    if (ok) {
      await _secureStorage.delete(key: _pinFailCount);
      await _secureStorage.delete(key: _pinLockUntil);
      return true;
    }

    await _registerFailedPinAttempt();
    return false;
  }

  Future<void> setPinCode(String pinCode) async {
    final hash = hashPinCode(pinCode);
    await _secureStorage.write(key: _userPinHash, value: hash);
    await _secureStorage.delete(key: _pinFailCount);
    await _secureStorage.delete(key: _pinLockUntil);
  }

  /// Сколько времени PIN-ввод заблокирован. `Duration.zero` — разблокирован.
  Future<Duration> remainingLockout() async {
    final raw = await _secureStorage.read(key: _pinLockUntil);
    if (raw == null) return Duration.zero;
    final until = DateTime.fromMillisecondsSinceEpoch(int.tryParse(raw) ?? 0);
    final diff = until.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Количество подряд неверных попыток PIN.
  Future<int> failedPinAttempts() async {
    final raw = await _secureStorage.read(key: _pinFailCount);
    return int.tryParse(raw ?? '') ?? 0;
  }

  Future<void> _registerFailedPinAttempt() async {
    final count = (await failedPinAttempts()) + 1;
    await _secureStorage.write(key: _pinFailCount, value: '$count');

    final step = count < _lockoutSteps.length
        ? _lockoutSteps[count]
        : _lockoutSteps.last;
    if (step > Duration.zero) {
      final until = DateTime.now().add(step).millisecondsSinceEpoch;
      await _secureStorage.write(key: _pinLockUntil, value: '$until');
    }
  }

  Future<void> clearAllSecureData() async {
    await _secureStorage.deleteAll();
  }
}
