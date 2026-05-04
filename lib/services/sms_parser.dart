import '../models/transaction.dart';
import 'transaction_deduplicator.dart';

/// Результат разбора одного SMS банка.
class ParsedBankMessage {
  ParsedBankMessage({
    required this.bankId,
    required this.amount,
    required this.type,
    required this.date,
    this.currency = 'RUB',
    this.merchant,
    this.cardMask,
    this.balanceAfter,
  });

  final String bankId;

  /// Положительная сумма; направление зашито в [type].
  final double amount;

  /// `'income'` или `'expense'`.
  final String type;
  final DateTime date;
  final String currency;
  final String? merchant;
  final String? cardMask;
  final double? balanceAfter;

  /// Превращает в `Transaction` со статусом «черновик».
  /// `accountId` ставим заглушкой — пользователь привяжет его при подтверждении.
  Transaction toDraft({String accountId = '__draft__'}) {
    final signed = type == 'income' ? amount : -amount;
    final fp = TransactionFingerprint.compute(
      date: date,
      amountSigned: signed,
      currency: currency,
      bankId: bankId,
      merchant: merchant,
      cardMask: cardMask,
    );
    return Transaction(
      id: fp,
      accountId: accountId,
      amount: amount,
      type: type,
      category: 'Другое',
      description: merchant ?? '',
      date: date,
      currency: currency,
      merchantName: merchant,
      source: TransactionSource.sms,
      bankId: bankId,
      externalId: fp,
      cardMask: cardMask,
      isDraft: true,
    );
  }
}

/// Парсер банковских SMS.
///
/// Подход: список регистронечувствительных «правил», каждое — для
/// конкретного банка. Берём первое правило, которое смогло распарсить.
/// Тексты сообщений собраны из реальных шаблонов 2023–2025 (Сбер,
/// Тинькофф/Т-Банк, Альфа, ВТБ); нестандартные сообщения (например,
/// "code 1234 — никому не сообщайте") отсеиваются по отсутствию суммы.
class SmsBankParser {
  /// Адресанты (sender id), по которым мы доверяем сообщению как банковскому.
  /// Сравнение — case-insensitive по `contains`.
  static const Map<String, List<String>> bankSenders = {
    'sber': ['900', 'sberbank', 'sber', 'сбер'],
    'tinkoff': ['tinkoff', 'tbank', 't-bank', 'т-банк', 'тинькофф'],
    'alfa': ['alfa', 'alfabank', 'альфа'],
    'vtb': ['vtb', 'втб', 'vtb-bank'],
  };

  /// Возвращает `bankId` по отправителю, либо `null` если не банк.
  static String? bankIdBySender(String sender) {
    final s = sender.toLowerCase();
    for (final entry in bankSenders.entries) {
      if (entry.value.any(s.contains)) return entry.key;
    }
    return null;
  }

  /// Главный вход: пробуем все правила.
  /// [now] — момент получения SMS (используется как fallback для даты).
  static ParsedBankMessage? parse(
    String body, {
    String? sender,
    DateTime? now,
  }) {
    final bankId = sender == null ? null : bankIdBySender(sender);
    final ts = now ?? DateTime.now();

    for (final rule in _rules) {
      if (bankId != null && rule.bankId != bankId) continue;
      final res = rule.tryParse(body, ts);
      if (res != null) return res;
    }
    // Если sender неизвестен, пробуем все правила в порядке приоритета.
    if (bankId == null) {
      for (final rule in _rules) {
        final res = rule.tryParse(body, ts);
        if (res != null) return res;
      }
    }
    return null;
  }

  static final List<_BankRule> _rules = [
    // ===== Сбер =====
    // Примеры:
    // "MIR-1234 02.05.26 19:32 Pokupka 1 234.56 RUB BARCODE Balans: 12 345.67 RUB"
    // "ECMC1234 03.05.26 12:00 Perevod 500р от ИВАН И. Баланс: 10 000р"
    _BankRule(
      bankId: 'sber',
      pattern: RegExp(
        r'(?<card>(?:MIR|ECMC|VISA|MAESTRO)-?\d{2,4})\s+'
        r'(?<dt>\d{2}\.\d{2}\.\d{2,4}(?:\s+\d{2}:\d{2}(?::\d{2})?)?)\s+'
        r'(?<op>Pokupka|Oplata|Perevod|Vozvrat|Spisanie|Zachislenie|Списание|Зачисление|Покупка|Перевод|Возврат|Оплата)\s+'
        r'(?<amt>[\d\s.,]+)\s*(?<cur>RUB|RUR|р|руб)',
        caseSensitive: false,
      ),
      build: (m, ts) {
        final op = m.namedGroup('op')!.toLowerCase();
        final isIncome = _isSberIncome(op);
        final card = _last4(m.namedGroup('card'));
        final amt = _amount(m.namedGroup('amt')!);
        final dt = _parseRuDate(m.namedGroup('dt')!) ?? ts;
        final merchant = _afterAmount(m.input, m.end);
        return amt == null
            ? null
            : ParsedBankMessage(
                bankId: 'sber',
                amount: amt,
                type: isIncome ? 'income' : 'expense',
                date: dt,
                cardMask: card,
                merchant: merchant,
              );
      },
    ),

    // ===== Тинькофф / Т-Банк =====
    // "Pokupka. Karta *1234. Summa 1234.56 RUB. ALFA-COFFEE. Dostupno 9876.54 RUB"
    // "Оплата. Карта *1234. Сумма 250 ₽. SAMOKAT. Доступно 12 345 ₽"
    _BankRule(
      bankId: 'tinkoff',
      pattern: RegExp(
        r'(?<op>Pokupka|Oplata|Perevod|Vozvrat|Popolnenie|Postuplenie|Spisanie|Покупка|Оплата|Перевод|Возврат|Пополнение|Поступление|Списание)'
        r'[\s\S]*?(?:Karta|Карта)\s*\*?(?<card>\d{4})'
        r'[\s\S]*?(?:Summa|Сумма)\s*(?<amt>[\d\s.,]+)\s*(?<cur>RUB|RUR|₽|р|руб)?'
        r'(?:[\s\S]*?\.\s*(?<merchant>[A-ZА-Я0-9*\-\s]{3,40}?))?'
        r'(?:[\s\S]*?(?:Dostupno|Доступно)\s*(?<bal>[\d\s.,]+))?',
        caseSensitive: false,
      ),
      build: (m, ts) {
        final op = m.namedGroup('op')!.toLowerCase();
        final isIncome = _isTinkoffIncome(op);
        final amt = _amount(m.namedGroup('amt')!);
        final card = m.namedGroup('card');
        final merchant = (m.namedGroup('merchant') ?? '').trim();
        return amt == null
            ? null
            : ParsedBankMessage(
                bankId: 'tinkoff',
                amount: amt,
                type: isIncome ? 'income' : 'expense',
                date: ts,
                cardMask: card,
                merchant: merchant.isEmpty ? null : merchant,
                balanceAfter: _amount(m.namedGroup('bal') ?? ''),
              );
      },
    ),

    // ===== Альфа-Банк =====
    // "Alfa-Bank: Pokupka 1234.56 RUR. Karta *1234. ALFA STORE. Dostupno: 5000.00 RUR"
    // "Альфа-Банк: Перевод 500 RUR. Карта *1234. ИВАН И."
    _BankRule(
      bankId: 'alfa',
      pattern: RegExp(
        r'Alfa[\s-]*Bank|Альфа[\s-]*Банк',
        caseSensitive: false,
      ),
      build: (m, ts) {
        final body = m.input;
        final opMatch = RegExp(
          r'(Pokupka|Oplata|Perevod|Vozvrat|Popolnenie|Spisanie|Покупка|Оплата|Перевод|Возврат|Пополнение|Списание)',
          caseSensitive: false,
        ).firstMatch(body);
        if (opMatch == null) return null;
        final op = opMatch.group(0)!.toLowerCase();

        final amtMatch = RegExp(
          r'([\d][\d\s.,]*)\s*(?:RUB|RUR|₽|р|руб)\b',
          caseSensitive: false,
        ).firstMatch(body);
        if (amtMatch == null) return null;
        final amt = _amount(amtMatch.group(1)!);
        if (amt == null) return null;

        final cardMatch =
            RegExp(r'(?:Karta|Карта)\s*\*?(\d{4})', caseSensitive: false)
                .firstMatch(body);

        final balMatch = RegExp(
          r'(?:Dostupno|Доступно)\s*:?\s*([\d\s.,]+)',
          caseSensitive: false,
        ).firstMatch(body);

        return ParsedBankMessage(
          bankId: 'alfa',
          amount: amt,
          type: _isAlfaIncome(op) ? 'income' : 'expense',
          date: ts,
          cardMask: cardMatch?.group(1),
          merchant: _afterAmount(body, amtMatch.end),
          balanceAfter: balMatch == null ? null : _amount(balMatch.group(1)!),
        );
      },
    ),

    // ===== ВТБ =====
    // "VTB: Pokupka 999.00r Karta *1234 02.05.26 19:32 SHOP NAME Ostatok 5000.00r"
    // "ВТБ: Списание 1500р Карта *1234 02.05 19:32 БАЛАНС 10000р"
    _BankRule(
      bankId: 'vtb',
      pattern: RegExp(
        r'\bVTB\b|\bВТБ\b',
        caseSensitive: false,
      ),
      build: (m, ts) {
        final body = m.input;
        final opMatch = RegExp(
          r'(Pokupka|Oplata|Perevod|Vozvrat|Popolnenie|Spisanie|Zachislenie|Покупка|Оплата|Перевод|Возврат|Пополнение|Списание|Зачисление)',
          caseSensitive: false,
        ).firstMatch(body);
        if (opMatch == null) return null;
        final op = opMatch.group(0)!.toLowerCase();

        final amtMatch = RegExp(
          r'([\d][\d\s.,]*)\s*(?:RUB|RUR|₽|р|руб)\b',
          caseSensitive: false,
        ).firstMatch(body);
        if (amtMatch == null) return null;
        final amt = _amount(amtMatch.group(1)!);
        if (amt == null) return null;

        final cardMatch =
            RegExp(r'(?:Karta|Карта)\s*\*?(\d{4})', caseSensitive: false)
                .firstMatch(body);
        final dt = _parseRuDate(
              RegExp(r'\d{2}\.\d{2}(?:\.\d{2,4})?(?:\s+\d{2}:\d{2}(?::\d{2})?)?')
                      .firstMatch(body)
                      ?.group(0) ??
                  '',
            ) ??
            ts;

        return ParsedBankMessage(
          bankId: 'vtb',
          amount: amt,
          type: _isVtbIncome(op) ? 'income' : 'expense',
          date: dt,
          cardMask: cardMatch?.group(1),
          merchant: _afterAmount(body, amtMatch.end),
        );
      },
    ),
  ];

  // ===== вспомогательные =====

  static bool _isSberIncome(String op) =>
      op.startsWith('zachisl') ||
      op.startsWith('зачисл') ||
      op.startsWith('vozvrat') ||
      op.startsWith('возврат') ||
      op.startsWith('postuplenie') ||
      op.startsWith('поступление');

  static bool _isTinkoffIncome(String op) =>
      op.startsWith('popoln') ||
      op.startsWith('пополн') ||
      op.startsWith('postup') ||
      op.startsWith('поступ') ||
      op.startsWith('vozvrat') ||
      op.startsWith('возврат');

  static bool _isAlfaIncome(String op) => _isTinkoffIncome(op);

  static bool _isVtbIncome(String op) =>
      op.startsWith('popoln') ||
      op.startsWith('пополн') ||
      op.startsWith('zachisl') ||
      op.startsWith('зачисл') ||
      op.startsWith('vozvrat') ||
      op.startsWith('возврат');

  static String? _last4(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'(\d{4})$').firstMatch(raw);
    return m?.group(1);
  }

  static double? _amount(String raw) {
    var s = raw
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('\u00A0', '')
        .replaceAll('₽', '')
        .replaceAll(
            RegExp(r'RUB|RUR|руб|р', caseSensitive: false), '');
    if (s.contains(',') && s.contains('.')) {
      if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
        s = s.replaceAll('.', '').replaceAll(',', '.');
      } else {
        s = s.replaceAll(',', '');
      }
    } else {
      s = s.replaceAll(',', '.');
    }
    final v = double.tryParse(s);
    if (v == null || v <= 0) return null;
    return v;
  }

  /// Парсит даты вида `dd.MM.yy[yy] [HH:mm[:ss]]` и `dd.MM HH:mm`.
  static DateTime? _parseRuDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final m = RegExp(
      r'^(\d{2})\.(\d{2})(?:\.(\d{2,4}))?(?:\s+(\d{2}):(\d{2})(?::(\d{2}))?)?',
    ).firstMatch(s);
    if (m == null) return null;
    final d = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    int year;
    final yRaw = m.group(3);
    if (yRaw == null) {
      year = DateTime.now().year;
    } else {
      year = int.parse(yRaw);
      if (year < 100) year += 2000;
    }
    final hh = int.tryParse(m.group(4) ?? '') ?? 0;
    final mm = int.tryParse(m.group(5) ?? '') ?? 0;
    final ss = int.tryParse(m.group(6) ?? '') ?? 0;
    return DateTime(year, mo, d, hh, mm, ss);
  }

  /// Берёт текст между концом матча суммы и следующей точкой/переводом строки —
  /// эвристика для имени мерчанта.
  static String? _afterAmount(String body, int from) {
    if (from >= body.length) return null;
    final tail = body.substring(from);
    final m = RegExp(r'[\.\n]\s*([A-ZА-ЯЁ0-9*\-\s\.]{3,40})').firstMatch(tail);
    final raw = m?.group(1)?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (RegExp(r'^(?:Dostupno|Доступно|Balans|Баланс|Ostatok|Остаток)',
            caseSensitive: false)
        .hasMatch(raw)) {
      return null;
    }
    return raw;
  }
}

class _BankRule {
  _BankRule({
    required this.bankId,
    required this.pattern,
    required this.build,
  });

  final String bankId;
  final RegExp pattern;
  final ParsedBankMessage? Function(RegExpMatch match, DateTime ts) build;

  ParsedBankMessage? tryParse(String body, DateTime ts) {
    final m = pattern.firstMatch(body);
    if (m == null) return null;
    return build(m, ts);
  }
}
