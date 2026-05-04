import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/transaction.dart';

/// Сервис дедупликации транзакций.
///
/// Решает три задачи:
///  1. **Импорт ↔ SMS/push** — одна и та же транзакция может прийти
///     и из выписки, и из SMS/push. Импортированные записи имеют
///     приоритет (точные данные банка), а SMS/push помечаются как
///     уже зарегистрированные и не дублируются.
///  2. **SMS ↔ push** — банк часто шлёт одно и то же сообщение
///     и как push, и как SMS. Мы их сводим в одну транзакцию.
///  3. **Повторный импорт** одной и той же выписки не плодит дубли.
///
/// Идея: каждая транзакция получает стабильный «отпечаток»
/// (`externalId`) — `SHA1` от характеристик. При наличии записи с тем
/// же отпечатком в окне ±[fuzzyWindow] мы считаем её дубликатом.
class TransactionDeduplicator {
  TransactionDeduplicator({
    Duration fuzzyWindow = const Duration(hours: 48),
    Duration sameSourceTightWindow = const Duration(minutes: 10),
  })  : _fuzzyWindow = fuzzyWindow,
        _tightWindow = sameSourceTightWindow;

  /// Окно для дедупликации между источниками (импорт ↔ SMS/push).
  /// Дата в SMS — момент операции, а в выписке — иногда дата проводки,
  /// которая может отличаться на сутки–двое. Берём ±48 часов.
  final Duration _fuzzyWindow;

  /// Окно для одинаковых источников (повторный импорт того же файла,
  /// дублирующий push после SMS). Тут отклонение должно быть минимальным.
  final Duration _tightWindow;

  /// Готовый отпечаток для уже созданной транзакции.
  static String fingerprintOf(Transaction t) =>
      TransactionFingerprint.compute(
        date: t.date,
        amountSigned: t.type == 'income' ? t.amount : -t.amount,
        currency: t.currency,
        bankId: t.bankId,
        merchant: t.merchantName,
        cardMask: t.cardMask,
      );

  /// Ищет в [existing] транзакцию-дубликат для [candidate].
  ///
  /// Возвращает найденный дубль или `null`. Логика:
  ///  * **Точное совпадение** по `externalId` (если у обеих он есть и из одного банка).
  ///  * **Fuzzy-match**: тот же знак суммы, та же сумма ±0.01,
  ///    та же валюта, и `|date_a - date_b| <= window`.
  ///    Окно — узкое, если `source` совпадает, иначе широкое.
  Transaction? findDuplicate(
    Transaction candidate,
    Iterable<Transaction> existing,
  ) {
    final candidateFp = candidate.externalId ?? fingerprintOf(candidate);
    final candidateAmountSigned =
        candidate.type == 'income' ? candidate.amount : -candidate.amount;

    Transaction? bestMatch;
    Duration bestDelta = const Duration(days: 365 * 100);

    for (final t in existing) {
      if (identical(t, candidate)) continue;

      // 1) Точное совпадение по отпечатку — самый надёжный сигнал.
      final tFp = t.externalId ?? fingerprintOf(t);
      if (candidateFp == tFp) return t;

      // 2) Fuzzy: разная категория/описание простительны.
      if (t.currency != candidate.currency) continue;
      final tAmountSigned = t.type == 'income' ? t.amount : -t.amount;
      if ((tAmountSigned - candidateAmountSigned).abs() > 0.01) continue;

      final delta = t.date.difference(candidate.date).abs();
      final window = (t.effectiveSource == candidate.effectiveSource)
          ? _tightWindow
          : _fuzzyWindow;
      if (delta > window) continue;

      // 3) Если есть маска карты у обеих — она должна совпадать.
      if (t.cardMask != null &&
          candidate.cardMask != null &&
          t.cardMask != candidate.cardMask) {
        continue;
      }

      // 4) Если есть merchant у обеих — нормализуем и сравниваем.
      if (t.merchantName != null &&
          candidate.merchantName != null &&
          _normalize(t.merchantName!) != _normalize(candidate.merchantName!)) {
        // Разные мерчанты при совпадении суммы и времени — редкий, но возможный
        // сценарий (две покупки на одну сумму). Не считаем дублем.
        continue;
      }

      if (delta < bestDelta) {
        bestDelta = delta;
        bestMatch = t;
      }
    }

    return bestMatch;
  }

  /// Сливает данные [draft] в уже существующую [primary].
  ///
  /// Пример: пришла транзакция из push (без точного merchant), потом
  /// её перекрыла та же транзакция из выписки — берём merchant из
  /// выписки, но сохраняем `cardMask` из push, если он точнее.
  ///
  /// Если `primary` была черновиком (`isDraft = true`), а `draft` —
  /// уже подтверждённая транзакция (например, из импорта), черновик
  /// перестаёт быть черновиком.
  Transaction mergeInto(Transaction primary, Transaction draft) {
    primary.merchantName ??= draft.merchantName;
    primary.cardMask ??= draft.cardMask;
    primary.bankId ??= draft.bankId;

    // Источник выбираем «более авторитетный».
    primary.source = _moreAuthoritative(primary.source, draft.source);

    // Категория из manual/import пересиливает SMS/push.
    if (_sourceRank(draft.source) > _sourceRank(primary.source) &&
        draft.category.isNotEmpty &&
        draft.category != 'Другое') {
      primary.category = draft.category;
    }

    // Не понижаем confirmed → draft.
    primary.isDraft = primary.isDraft && draft.isDraft;

    return primary;
  }

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-zа-яё0-9]'), '')
      .trim();

  int _sourceRank(String? s) {
    switch (s) {
      case TransactionSource.manual:
        return 4;
      case TransactionSource.api:
        return 3;
      case TransactionSource.statementImport:
        return 3;
      case TransactionSource.push:
        return 2;
      case TransactionSource.sms:
        return 1;
      default:
        return 0;
    }
  }

  String? _moreAuthoritative(String? a, String? b) {
    return _sourceRank(a) >= _sourceRank(b) ? a : b;
  }
}

/// Чистая функция вычисления отпечатка транзакции.
class TransactionFingerprint {
  /// Округляет дату до минуты — в SMS/push секунды отсутствуют, а в
  /// выписках они часто 00.
  static String compute({
    required DateTime date,
    required double amountSigned,
    String currency = 'RUB',
    String? bankId,
    String? merchant,
    String? cardMask,
  }) {
    final minute = DateTime(
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
    );
    // Округляем сумму до копеек, чтобы 1500.0 и 1500.00 совпадали.
    final cents = (amountSigned * 100).round();
    final normalizedMerchant = (merchant ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zа-яё0-9]'), '');
    final raw = [
      minute.toIso8601String(),
      cents.toString(),
      currency,
      bankId ?? '',
      normalizedMerchant,
      cardMask ?? '',
    ].join('|');
    return sha1.convert(utf8.encode(raw)).toString();
  }
}
