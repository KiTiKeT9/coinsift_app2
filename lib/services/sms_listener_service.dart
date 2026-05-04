import 'dart:async';
import 'dart:io' show Platform;

import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';
import '../providers/transactions_provider.dart';
import 'sms_parser.dart';

/// Сервис чтения банковских SMS и постановки их в очередь черновиков.
///
/// Работает только на Android. На остальных платформах все методы — no-op.
///
/// Состояние хранится в `SharedPreferences`:
///  * `sms_listener_enabled` — пользовательский флаг,
///  * `sms_last_imported_at` — миллисекунды последней успешно
///    обработанной SMS, чтобы не сканировать inbox с нуля каждый раз.
class SmsListenerService {
  SmsListenerService(this._transactionsProvider);

  static const String _prefEnabled = 'sms_listener_enabled';
  static const String _prefLastImportedAt = 'sms_last_imported_at';

  final TransactionsProvider _transactionsProvider;
  final Telephony _telephony = Telephony.instance;
  StreamSubscription<SmsMessage>? _liveSub;

  static Future<bool> isEnabled() async {
    if (!Platform.isAndroid) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabled) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, value);
  }

  /// Запрашивает рантайм-разрешения SMS. Возвращает `true`, если выданы.
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return false;
    final granted = await _telephony.requestSmsPermissions;
    return granted ?? false;
  }

  /// Разовый импорт банковских SMS из inbox.
  ///
  /// Если у пользователя уже выполнялся импорт ранее, читаем только новые
  /// сообщения (по `date >= sms_last_imported_at`).
  /// Возвращает количество распознанных и попавших в БД черновиков.
  Future<int> importInbox() async {
    if (!Platform.isAndroid) return 0;
    final granted = await requestPermissions();
    if (!granted) return 0;

    final prefs = await SharedPreferences.getInstance();
    final lastTs = prefs.getInt(_prefLastImportedAt);

    final messages = await _telephony.getInboxSms(
      columns: const [
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
      ],
      filter: lastTs == null
          ? null
          : SmsFilter.where(SmsColumn.DATE).greaterThan(lastTs.toString()),
    );

    final drafts = <Transaction>[];
    int maxTs = lastTs ?? 0;

    for (final m in messages) {
      final body = m.body ?? '';
      if (body.isEmpty) continue;
      final sender = m.address ?? '';
      final ts = m.date;
      if (ts != null && ts > maxTs) maxTs = ts;

      final parsed = SmsBankParser.parse(
        body,
        sender: sender,
        now: ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts),
      );
      if (parsed == null) continue;
      drafts.add(parsed.toDraft());
    }

    if (drafts.isEmpty) {
      if (maxTs > (lastTs ?? 0)) {
        await prefs.setInt(_prefLastImportedAt, maxTs);
      }
      return 0;
    }

    final stats = await _transactionsProvider.bulkImport(drafts);
    if (maxTs > 0) await prefs.setInt(_prefLastImportedAt, maxTs);
    return stats.added + stats.merged;
  }

  /// Подписаться на входящие SMS в реальном времени.
  /// Foreground-only: при killed-процессе доставку не гарантируем
  /// (для этого нужен @pragma('vm:entry-point') backgroundHandler,
  /// что выходит за рамки phase 2 — сделаем позже отдельным шагом).
  Future<void> startLiveListening() async {
    if (!Platform.isAndroid) return;
    if (_liveSub != null) return;
    final granted = await requestPermissions();
    if (!granted) return;

    _telephony.listenIncomingSms(
      onNewMessage: _handleIncoming,
      listenInBackground: false,
    );
  }

  Future<void> stopLiveListening() async {
    await _liveSub?.cancel();
    _liveSub = null;
  }

  Future<void> _handleIncoming(SmsMessage message) async {
    try {
      final parsed = SmsBankParser.parse(
        message.body ?? '',
        sender: message.address ?? '',
        now: message.date == null
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(message.date!),
      );
      if (parsed == null) return;
      await _transactionsProvider.bulkImport([parsed.toDraft()]);
    } catch (e, st) {
      debugPrint('SMS handle error: $e\n$st');
    }
  }
}
