import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../services/push_listener_service.dart';
import '../services/sms_listener_service.dart';
import 'transactions_provider.dart';

/// Единая точка включения/выключения «банковских сигналов» —
/// чтения SMS и прослушки push-уведомлений банков.
///
/// Хранит пользовательские флаги (через `SmsListenerService.isEnabled`
/// и `PushListenerService.isEnabled`) и запускает/останавливает
/// соответствующие платформенные подписки.
///
/// Используется как `ChangeNotifierProxyProvider<TransactionsProvider,
/// BankSignalsController>` в `main.dart`, чтобы сервисы имели доступ
/// к `TransactionsProvider.bulkImport`.
class BankSignalsController extends ChangeNotifier {
  BankSignalsController(TransactionsProvider transactions)
      : sms = SmsListenerService(transactions),
        push = PushListenerService(transactions);

  final SmsListenerService sms;
  final PushListenerService push;

  bool _smsEnabled = false;
  bool _pushEnabled = false;
  bool _pushPermissionGranted = false;
  int _lastImportedDrafts = 0;

  bool get smsEnabled => _smsEnabled;
  bool get pushEnabled => _pushEnabled;
  bool get pushPermissionGranted => _pushPermissionGranted;
  bool get isAndroid => Platform.isAndroid;
  int get lastImportedDrafts => _lastImportedDrafts;

  /// Проверка инварианта от `ChangeNotifierProxyProvider.update`.
  ///
  /// `TransactionsProvider` создаётся один раз в корневом `MultiProvider`
  /// и не пересоздаётся при перестройке дерева, поэтому реального
  /// «обновления» тут не нужно — сервисы получили инстанс в конструкторе.
  void updateTransactions(TransactionsProvider value) {
    // no-op by design
  }

  /// Считывает состояние из `SharedPreferences` и, если пользователь уже
  /// включал интеграции ранее, запускает их сейчас.
  ///
  /// Безопасно вызывать несколько раз — повторные `start()` — no-op.
  Future<void> autoStart() async {
    if (!Platform.isAndroid) return;
    _smsEnabled = await SmsListenerService.isEnabled();
    _pushEnabled = await PushListenerService.isEnabled();
    _pushPermissionGranted = await push.isPermissionGranted();

    if (_smsEnabled) {
      unawaited(_importInboxSafe());
      unawaited(sms.startLiveListening());
    }
    if (_pushEnabled && _pushPermissionGranted) {
      unawaited(push.start());
    }
    notifyListeners();
  }

  /// Переключатель «Импорт SMS».
  /// При включении — сразу запрашивает permissions, импортирует inbox
  /// и подписывается на live-сообщения.
  Future<void> setSmsEnabled(bool value) async {
    if (!Platform.isAndroid) return;
    if (value) {
      final granted = await sms.requestPermissions();
      if (!granted) {
        // Разрешения не выданы — оставляем выключенным.
        _smsEnabled = false;
        await SmsListenerService.setEnabled(false);
        notifyListeners();
        return;
      }
      await SmsListenerService.setEnabled(true);
      _smsEnabled = true;
      notifyListeners();
      _lastImportedDrafts = await sms.importInbox();
      unawaited(sms.startLiveListening());
    } else {
      await SmsListenerService.setEnabled(false);
      await sms.stopLiveListening();
      _smsEnabled = false;
    }
    notifyListeners();
  }

  /// Переключатель «Доступ к push-уведомлениям».
  /// Если доступа нет — открывает системные настройки; пользователь
  /// возвращается в приложение с результатом, мы перечитываем статус.
  Future<void> setPushEnabled(bool value) async {
    if (!Platform.isAndroid) return;
    if (value) {
      final hasPermission = await push.isPermissionGranted();
      if (!hasPermission) {
        final granted = await push.requestPermission();
        _pushPermissionGranted = granted;
        if (!granted) {
          _pushEnabled = false;
          await PushListenerService.setEnabled(false);
          notifyListeners();
          return;
        }
      } else {
        _pushPermissionGranted = true;
      }
      await PushListenerService.setEnabled(true);
      _pushEnabled = true;
      await push.start();
    } else {
      await PushListenerService.setEnabled(false);
      await push.stop();
      _pushEnabled = false;
    }
    notifyListeners();
  }

  /// Ручной триггер «импортировать inbox сейчас» — для кнопки на Профиле.
  Future<int> importSmsInboxNow() async {
    if (!Platform.isAndroid) return 0;
    if (!_smsEnabled) return 0;
    final n = await sms.importInbox();
    _lastImportedDrafts = n;
    notifyListeners();
    return n;
  }

  Future<void> _importInboxSafe() async {
    try {
      _lastImportedDrafts = await sms.importInbox();
      notifyListeners();
    } catch (e, st) {
      debugPrint('SMS inbox import failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    sms.stopLiveListening();
    push.stop();
    super.dispose();
  }
}
