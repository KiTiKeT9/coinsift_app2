import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';
import 'transaction_deduplicator.dart';

/// Описание поддерживаемого банка/формата для импорта выписок.
class BankFormat {
  const BankFormat({
    required this.id,
    required this.name,
    required this.shortName,
    required this.colorHex,
    required this.supportedExtensions,
    required this.exportSteps,
  });

  final String id;
  final String name;
  final String shortName;
  final String colorHex;
  final List<String> supportedExtensions;
  final List<String> exportSteps;
}

/// Каталог поддерживаемых банков с инструкциями для пользователя.
class SupportedBanks {
  static const List<BankFormat> all = [
    BankFormat(
      id: 'tinkoff',
      name: 'Тинькофф / Т-Банк',
      shortName: 'Тинькофф',
      colorHex: '#FFDD2D',
      supportedExtensions: ['csv'],
      exportSteps: [
        'Откройте мобильное приложение Т-Банк (или личный кабинет на tbank.ru).',
        'Перейдите на нужный счёт или карту.',
        'Нажмите "Выписка" → выберите период.',
        'Нажмите "Скачать" и выберите формат CSV.',
        'Сохраните файл и загрузите его здесь.',
      ],
    ),
    BankFormat(
      id: 'sber',
      name: 'СберБанк',
      shortName: 'Сбер',
      colorHex: '#21A038',
      supportedExtensions: ['csv', 'xlsx'],
      exportSteps: [
        'Откройте СберБанк Онлайн в браузере (online.sberbank.ru).',
        'Выберите карту или счёт → "История операций".',
        'Задайте период и нажмите "Сохранить выписку".',
        'Выберите формат CSV или Excel.',
        'Загрузите полученный файл здесь.',
      ],
    ),
    BankFormat(
      id: 'alfa',
      name: 'Альфа-Банк',
      shortName: 'Альфа',
      colorHex: '#EF3124',
      supportedExtensions: ['csv', 'xlsx'],
      exportSteps: [
        'Войдите в Альфа-Онлайн на сайте online.alfabank.ru.',
        'Откройте счёт/карту → "Операции".',
        'Выберите период → "Скачать в Excel" или "Скачать в CSV".',
        'Загрузите файл здесь.',
      ],
    ),
    BankFormat(
      id: 'vtb',
      name: 'ВТБ',
      shortName: 'ВТБ',
      colorHex: '#0A2973',
      supportedExtensions: ['csv', 'xlsx'],
      exportSteps: [
        'Откройте ВТБ Онлайн на online.vtb.ru.',
        'Выберите карту/счёт → "Получить выписку".',
        'Укажите период и формат (Excel или CSV).',
        'Загрузите файл здесь.',
      ],
    ),
    BankFormat(
      id: 'ofx',
      name: 'OFX (универсальный)',
      shortName: 'OFX',
      colorHex: '#6366F1',
      supportedExtensions: ['ofx', 'qfx'],
      exportSteps: [
        'Многие интернет-банки умеют экспортировать выписку в формате OFX/QFX.',
        'Найдите этот формат в разделе "Экспорт выписки" вашего банка.',
        'Загрузите файл здесь.',
      ],
    ),
  ];

  static BankFormat byId(String id) =>
      all.firstWhere((b) => b.id == id, orElse: () => all.last);
}

/// Сервис импорта банковских выписок (CSV / XLSX / OFX).
///
/// Все полученные транзакции получают:
///   * `source = TransactionSource.statementImport`
///   * `bankId` — идентификатор банка из [SupportedBanks]
///   * `externalId` — стабильный fingerprint для дедупликации
///   * `isDraft = false` — импорт сразу учитывается
///
/// Дедупликация выполняется на стороне `TransactionsProvider.bulkImport`.
class BankStatementImportService {
  static const String _prefsKey = 'bank_import_enabled';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
  }

  /// Открыть системный диалог выбора файла выписки.
  static Future<File?> pickStatementFile() async {
    const typeGroup = XTypeGroup(
      label: 'Bank Statements',
      extensions: ['csv', 'xlsx', 'xls', 'ofx', 'qfx'],
    );
    final picked = await openFile(acceptedTypeGroups: [typeGroup]);
    return picked == null ? null : File(picked.path);
  }

  /// Импорт транзакций из выбранного файла.
  ///
  /// [bankId] — пресет банка (`tinkoff`, `sber`, ...). Если `null`,
  /// сервис попытается определить формат автоматически по заголовкам.
  static Future<ImportResult> importFromFile(
    File file, {
    required String accountId,
    String? bankId,
  }) async {
    try {
      final ext = path.extension(file.path).toLowerCase();
      final BankFormat bank = bankId != null
          ? SupportedBanks.byId(bankId)
          : _guessBankByExtension(ext);

      List<Transaction> transactions;
      int totalRows;
      int skipped;

      if (ext == '.csv') {
        final parsed = await _importCsv(file, bank: bank, accountId: accountId);
        transactions = parsed.transactions;
        totalRows = parsed.totalRows;
        skipped = parsed.skipped;
      } else if (ext == '.xlsx' || ext == '.xls') {
        final parsed =
            await _importExcel(file, bank: bank, accountId: accountId);
        transactions = parsed.transactions;
        totalRows = parsed.totalRows;
        skipped = parsed.skipped;
      } else if (ext == '.ofx' || ext == '.qfx') {
        final parsed = await _importOfx(file, accountId: accountId);
        transactions = parsed.transactions;
        totalRows = parsed.totalRows;
        skipped = parsed.skipped;
      } else {
        return ImportResult.failure(
          'Неподдерживаемый формат: $ext. Используйте CSV, XLSX, XLS или OFX.',
        );
      }

      return ImportResult(
        success: true,
        transactions: transactions,
        totalRows: totalRows,
        importedRows: transactions.length,
        skippedRows: skipped,
        bankId: bank.id,
      );
    } catch (e, st) {
      debugPrint('Import error: $e\n$st');
      return ImportResult.failure('Ошибка импорта: $e');
    }
  }

  // ===== CSV =====

  static Future<_ParsedRows> _importCsv(
    File file, {
    required BankFormat bank,
    required String accountId,
  }) async {
    // Читаем как байты и пробуем UTF-8/Windows-1251.
    final bytes = await file.readAsBytes();
    String content;
    try {
      content = String.fromCharCodes(bytes); // best-effort
      // эвристика: если много "?" и нет кириллицы, перечитываем как latin1
    } catch (_) {
      content = String.fromCharCodes(bytes);
    }

    // Поддерживаем разделители ; и ,
    final separator = content.contains(';') ? ';' : ',';
    final converter = CsvDecoder(
      fieldDelimiter: separator,
      dynamicTyping: false,
    );
    final rows = converter.convert(content);

    if (rows.isEmpty) return const _ParsedRows([], 0, 0);

    final headers =
        rows.first.map((h) => h.toString().trim().toLowerCase()).toList();
    final mapping = _BankMapping.fromHeaders(headers, bank);

    final result = <Transaction>[];
    int skipped = 0;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final tx = _rowToTransaction(
        row,
        mapping: mapping,
        bank: bank,
        accountId: accountId,
      );
      if (tx != null) {
        result.add(tx);
      } else {
        skipped++;
      }
    }
    return _ParsedRows(result, rows.length - 1, skipped);
  }

  // ===== XLSX =====

  static Future<_ParsedRows> _importExcel(
    File file, {
    required BankFormat bank,
    required String accountId,
  }) async {
    final bytes = await file.readAsBytes();
    final book = xlsx.Excel.decodeBytes(bytes);
    final sheetName = book.tables.keys.first;
    final sheet = book.tables[sheetName]!;
    final rows = sheet.rows
        .map((r) => r.map((c) => c?.value?.toString() ?? '').toList())
        .toList();

    if (rows.isEmpty) return const _ParsedRows([], 0, 0);

    final headers =
        rows.first.map((h) => h.toString().trim().toLowerCase()).toList();
    final mapping = _BankMapping.fromHeaders(headers, bank);

    final result = <Transaction>[];
    int skipped = 0;
    for (int i = 1; i < rows.length; i++) {
      final tx = _rowToTransaction(
        rows[i],
        mapping: mapping,
        bank: bank,
        accountId: accountId,
      );
      if (tx != null) {
        result.add(tx);
      } else {
        skipped++;
      }
    }
    return _ParsedRows(result, rows.length - 1, skipped);
  }

  // ===== OFX =====

  /// Простой парсер OFX 1.x (SGML-вариант) и 2.x (XML).
  /// Извлекает блоки `<STMTTRN>` без полноценного XML-парсера.
  static Future<_ParsedRows> _importOfx(
    File file, {
    required String accountId,
  }) async {
    final content = await file.readAsString();
    final txRegex = RegExp(
      r'<STMTTRN>([\s\S]*?)</STMTTRN>',
      caseSensitive: false,
    );

    final transactions = <Transaction>[];
    int skipped = 0;
    int total = 0;
    for (final m in txRegex.allMatches(content)) {
      total++;
      final block = m.group(1) ?? '';
      String? tag(String name) => RegExp(
            '<$name>([^<\\r\\n]*)',
            caseSensitive: false,
          ).firstMatch(block)?.group(1)?.trim();

      final amountStr = tag('TRNAMT');
      final dateStr = tag('DTPOSTED');
      final memo = tag('MEMO') ?? tag('NAME') ?? '';
      if (amountStr == null || dateStr == null) {
        skipped++;
        continue;
      }
      final amount = double.tryParse(amountStr);
      if (amount == null) {
        skipped++;
        continue;
      }
      final date = _parseOfxDate(dateStr);
      if (date == null) {
        skipped++;
        continue;
      }
      transactions.add(_buildTransaction(
        accountId: accountId,
        bankId: 'ofx',
        date: date,
        amountSigned: amount,
        merchant: memo,
        description: memo,
        category: _categoryFromMerchant(memo),
      ));
    }
    return _ParsedRows(transactions, total, skipped);
  }

  static DateTime? _parseOfxDate(String raw) {
    // YYYYMMDD или YYYYMMDDHHMMSS
    if (raw.length < 8) return null;
    final y = int.tryParse(raw.substring(0, 4));
    final m = int.tryParse(raw.substring(4, 6));
    final d = int.tryParse(raw.substring(6, 8));
    if (y == null || m == null || d == null) return null;
    int hh = 0, mm = 0, ss = 0;
    if (raw.length >= 14) {
      hh = int.tryParse(raw.substring(8, 10)) ?? 0;
      mm = int.tryParse(raw.substring(10, 12)) ?? 0;
      ss = int.tryParse(raw.substring(12, 14)) ?? 0;
    }
    return DateTime(y, m, d, hh, mm, ss);
  }

  // ===== Row → Transaction =====

  static Transaction? _rowToTransaction(
    List<dynamic> row, {
    required _BankMapping mapping,
    required BankFormat bank,
    required String accountId,
  }) {
    String? cell(int? idx) {
      if (idx == null || idx < 0 || idx >= row.length) return null;
      final v = row[idx];
      return v?.toString().trim();
    }

    final dateStr = cell(mapping.dateIdx);
    final amountStr = cell(mapping.amountIdx);
    if (dateStr == null || amountStr == null) return null;

    final date = _parseDate(dateStr);
    final amount = _parseAmount(amountStr);
    if (date == null || amount == 0) return null;

    final description = cell(mapping.descriptionIdx) ?? '';
    final category = cell(mapping.categoryIdx) ?? '';
    final mcc = cell(mapping.mccIdx);
    final cardMask = _extractCardMask(description);

    return _buildTransaction(
      accountId: accountId,
      bankId: bank.id,
      date: date,
      amountSigned: amount,
      merchant: description,
      description: description,
      category: _normalizeCategory(category, mcc, description),
      cardMask: cardMask,
    );
  }

  static Transaction _buildTransaction({
    required String accountId,
    required String bankId,
    required DateTime date,
    required double amountSigned,
    required String description,
    required String merchant,
    required String category,
    String? cardMask,
  }) {
    final type = amountSigned > 0 ? 'income' : 'expense';
    final amountAbs = amountSigned.abs();
    final fp = TransactionFingerprint.compute(
      date: date,
      amountSigned: amountSigned,
      bankId: bankId,
      merchant: merchant,
      cardMask: cardMask,
    );
    return Transaction(
      id: fp, // используем fingerprint как id для повторяемости
      accountId: accountId,
      amount: amountAbs,
      type: type,
      category: category,
      description: description,
      date: date,
      merchantName: merchant.isEmpty ? null : merchant,
      source: TransactionSource.statementImport,
      bankId: bankId,
      externalId: fp,
      cardMask: cardMask,
    );
  }

  // ===== Парсинг даты =====

  static final List<DateFormat> _dateFormats = [
    DateFormat('dd.MM.yyyy HH:mm:ss'),
    DateFormat('dd.MM.yyyy HH:mm'),
    DateFormat('dd.MM.yyyy'),
    DateFormat('dd.MM.yy'),
    DateFormat('dd/MM/yyyy HH:mm'),
    DateFormat('dd/MM/yyyy'),
    DateFormat('yyyy-MM-dd HH:mm:ss'),
    DateFormat('yyyy-MM-dd HH:mm'),
    DateFormat('yyyy-MM-dd'),
    DateFormat('dd-MM-yyyy'),
  ];

  static DateTime? _parseDate(String raw) {
    final str = raw.trim();
    if (str.isEmpty) return null;

    for (final f in _dateFormats) {
      try {
        return f.parseStrict(str);
      } catch (_) {
        // пробуем следующий
      }
    }
    // Последний шанс — ISO
    return DateTime.tryParse(str);
  }

  // ===== Парсинг суммы =====

  static double _parseAmount(String raw) {
    var str = raw
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('\u00A0', '')
        .replaceAll('₽', '')
        .replaceAll('RUB', '')
        .replaceAll(r'$', '')
        .replaceAll('€', '');

    // Если есть и запятая, и точка — последняя по позиции считается десятичным.
    if (str.contains(',') && str.contains('.')) {
      if (str.lastIndexOf(',') > str.lastIndexOf('.')) {
        str = str.replaceAll('.', '').replaceAll(',', '.');
      } else {
        str = str.replaceAll(',', '');
      }
    } else {
      str = str.replaceAll(',', '.');
    }
    return double.tryParse(str) ?? 0;
  }

  // ===== Нормализация категории =====

  static String _normalizeCategory(String raw, String? mcc, String description) {
    if (mcc != null && mcc.isNotEmpty) {
      final byMcc = _categoryByMcc(mcc);
      if (byMcc != 'Другое') return byMcc;
    }
    if (raw.isNotEmpty) {
      final mapped = _categoryFromText(raw);
      if (mapped != 'Другое') return mapped;
    }
    return _categoryFromMerchant(description);
  }

  static String _categoryByMcc(String mcc) {
    final code = int.tryParse(mcc);
    if (code == null) return 'Другое';
    if (code >= 5411 && code <= 5499) return 'Продукты';
    if (code >= 5811 && code <= 5814) return 'Рестораны';
    if (code == 4111 || code == 4131) return 'Транспорт';
    if (code == 4121) return 'Такси';
    if (code >= 7922 && code <= 7999) return 'Развлечения';
    if (code >= 5912 && code <= 5913) return 'Здоровье';
    if (code >= 5611 && code <= 5699) return 'Одежда';
    if (code >= 4900 && code <= 4999) return 'Коммуналка';
    if (code == 4899 || code == 4814) return 'Связь';
    if (code >= 8211 && code <= 8299) return 'Образование';
    if (code >= 7011 && code <= 7012) return 'Отель';
    return 'Другое';
  }

  static String _categoryFromText(String raw) =>
      _categoryFromMerchant(raw.toLowerCase());

  static String _categoryFromMerchant(String raw) {
    final s = raw.toLowerCase();
    bool any(List<String> patterns) => patterns.any(s.contains);

    if (any(['продукт', 'магнит', 'пятёрочк', 'пятерочк', 'перекрёстк', 'перекрестк', 'ашан', 'лента', 'дикси', 'grocery', 'supermarket'])) return 'Продукты';
    if (any(['ресторан', 'кафе', 'pizza', 'burger', 'mcdonald', 'kfc', 'starbucks', 'restaurant'])) return 'Рестораны';
    if (any(['метро', 'автобус', 'троллейбус', 'трамвай', 'rzd', 'ржд'])) return 'Транспорт';
    if (any(['такси', 'taxi', 'yandex go', 'uber', 'ситимобил', 'gett'])) return 'Такси';
    if (any(['azs', 'азс', 'лукойл', 'газпром', 'роснефть', 'shell', 'bp '])) return 'Бензин';
    if (any(['кино', 'cinema', 'netflix', 'okko', 'ivi', 'кинопоиск', 'spotify', 'youtube premium'])) return 'Развлечения';
    if (any(['аптек', 'pharmacy', '36.6', 'ригла', 'озерки'])) return 'Аптека';
    if (any(['клиника', 'медцентр', 'инвитро', 'гемотест', 'helix'])) return 'Здоровье';
    if (any(['lamoda', 'wildberries', 'wb ', 'ozon', 'h&m', 'zara', 'uniqlo'])) return 'Одежда';
    if (any(['жкх', 'коммунал', 'utilities', 'мосэнерго', 'водоканал'])) return 'Коммуналка';
    if (any(['мегафон', 'мтс', 'билайн', 'beeline', 'tele2', 'yota', 'rostelecom'])) return 'Связь';
    if (any(['зарплат', 'salary', 'аванс'])) return 'Зарплата';
    if (any(['перевод', 'transfer', 'p2p', 'sbp'])) return 'Переводы';
    if (any(['airbnb', 'отель', 'hotel', 'booking'])) return 'Отель';
    if (any(['s7', 'аэрофлот', 'победа', 'utair', 'airlines'])) return 'Путешествия';
    return 'Другое';
  }

  // Извлекает маску `*1234` или `**** 1234` из описания
  static String? _extractCardMask(String description) {
    final m = RegExp(r'(?:\*+|\.{2,})\s*(\d{4})').firstMatch(description);
    return m?.group(1);
  }

  static BankFormat _guessBankByExtension(String ext) {
    if (ext == '.ofx' || ext == '.qfx') return SupportedBanks.byId('ofx');
    return SupportedBanks.all.first;
  }
}

class _ParsedRows {
  const _ParsedRows(this.transactions, this.totalRows, this.skipped);
  final List<Transaction> transactions;
  final int totalRows;
  final int skipped;
}

class _BankMapping {
  _BankMapping({
    required this.dateIdx,
    required this.amountIdx,
    this.descriptionIdx,
    this.categoryIdx,
    this.mccIdx,
  });

  final int dateIdx;
  final int amountIdx;
  final int? descriptionIdx;
  final int? categoryIdx;
  final int? mccIdx;

  /// Ищет колонки по заголовкам с учётом конкретного банка.
  static _BankMapping fromHeaders(List<String> headers, BankFormat bank) {
    int? find(List<String> names) {
      for (int i = 0; i < headers.length; i++) {
        final h = headers[i];
        if (names.any((n) => h.contains(n))) return i;
      }
      return null;
    }

    final dateIdx = find([
      'дата операции',
      'дата проведения',
      'дата платежа',
      'дата',
      'date',
      'operation_date',
    ]);
    final amountIdx = find([
      'сумма в валюте счёта',
      'сумма в валюте счета',
      'сумма операции',
      'сумма платежа',
      'сумма',
      'amount',
    ]);
    final descriptionIdx = find([
      'описание',
      'назначение',
      'детали',
      'description',
      'memo',
      'name',
      'название',
    ]);
    final categoryIdx = find(['категория', 'category']);
    final mccIdx = find(['mcc', 'мсс']);

    return _BankMapping(
      dateIdx: dateIdx ?? 0,
      amountIdx: amountIdx ?? 1,
      descriptionIdx: descriptionIdx,
      categoryIdx: categoryIdx,
      mccIdx: mccIdx,
    );
  }
}

/// Результат импорта выписки.
class ImportResult {
  ImportResult({
    required this.success,
    this.transactions = const [],
    this.error,
    this.totalRows = 0,
    this.importedRows = 0,
    this.skippedRows = 0,
    this.bankId,
  });

  factory ImportResult.failure(String message) =>
      ImportResult(success: false, error: message);

  final bool success;
  final List<Transaction> transactions;
  final String? error;
  final int totalRows;
  final int importedRows;
  final int skippedRows;
  final String? bankId;
}
