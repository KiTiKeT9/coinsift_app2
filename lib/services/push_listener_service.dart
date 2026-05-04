import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';
import '../providers/transactions_provider.dart';
import 'sms_parser.dart';

/// Сервис прослушивания push-уведомлений банковских приложений.
///
/// Идея: подписываемся на системный stream `NotificationListenerService`
/// и для известных банковских пакетов прогоняем title+content через
/// тот же [SmsBankParser]. Дальше — `bulkImport`, который через
/// `TransactionDeduplicator` сольёт push с уже пришедшим SMS, чтобы
/// одна и та же операция не считалась дважды.
class PushListenerService {
  PushListenerService(this._transactionsProvider);

  static const String _prefEnabled = 'push_listener_enabled';

  final TransactionsProvider _transactionsProvider;
  StreamSubscription<ServiceNotificationEvent>? _sub;

  /// `package name -> bankId`. Пакеты — каноничные ID РФ-банков.
  static const Map<String, String> bankByPackage = {
    'ru.sberbankmobile': 'sber',
    'ru.sberbank.android': 'sber',
    'com.idamob.tinkoff.android': 'tinkoff',
    'ru.tinkoff.android': 'tinkoff',
    'ru.alfabank.mobile.android': 'alfa',
    'ru.alfabank.oavdo.amc': 'alfa',
    'ru.vtb24.mobilebanking.android': 'vtb',
    'com.vtb.mobilebank': 'vtb',
    'ru.vtb.online': 'vtb',
  };

  static Future<bool> isEnabled() async {
    if (!Platform.isAndroid) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabled) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, value);
  }

  /// Проверить, выдан ли пользователем доступ к шторке уведомлений.
  Future<bool> isPermissionGranted() async {
    if (!Platform.isAndroid) return false;
    return NotificationListenerService.isPermissionGranted();
  }

  /// Открывает системный экран «Доступ к уведомлениям» и ждёт результат.
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    return NotificationListenerService.requestPermission();
  }

  /// Подписывается на push-поток. Обновления от не-банковских приложений
  /// игнорируются. Возвращает `true`, если подписка реально стартовала.
  Future<bool> start() async {
    if (!Platform.isAndroid) return false;
    if (_sub != null) return true;

    final granted = await isPermissionGranted();
    if (!granted) return false;

    _sub = NotificationListenerService.notificationsStream
        .listen(_handleEvent, onError: (Object e, StackTrace st) {
      debugPrint('Push listener error: $e\n$st');
    });
    return true;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _handleEvent(ServiceNotificationEvent event) async {
    try {
      if (event.hasRemoved == true) return;
      final pkg = event.packageName;
      if (pkg == null) return;
      final bankId = bankByPackage[pkg];
      if (bankId == null) return;

      final body = [event.title ?? '', event.content ?? '']
          .where((s) => s.isNotEmpty)
          .join('. ');
      if (body.isEmpty) return;

      final parsed = SmsBankParser.parse(body, sender: bankId);
      if (parsed == null) return;

      final draft = parsed.toDraft();
      // Перезаписываем источник — это не SMS, а push.
      draft.source = TransactionSource.push;
      // bankId из пакета авторитетнее, чем угаданный по тексту.
      draft.bankId = bankId;

      await _transactionsProvider.bulkImport([draft]);
    } catch (e, st) {
      debugPrint('Push handle error: $e\n$st');
    }
  }
}

