import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

/// Сервис для импорта банковских выписок из файлов (CSV, Excel)
class BankStatementImportService {
  static const String _prefsKey = 'bank_import_enabled';

  /// Включён ли импорт выписок
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  /// Включить/выключить импорт
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
  }

  /// Выбор файла выписки
  static Future<File?> pickStatementFile() async {
    const typeGroup = XTypeGroup(
      label: 'Bank Statements',
      extensions: ['csv', 'xlsx', 'xls'],
    );

    final file = await openFile(
      acceptedTypeGroups: [typeGroup],
    );

    if (file != null) {
      return File(file.path);
    }
    return null;
  }

  /// Импорт транзакций из файла
  /// Возвращает количество импортированных транзакций
  static Future<ImportResult> importFromFile(File file, {String? accountId}) async {
    try {
      final extension = path.extension(file.path).toLowerCase();
      
      List<List<dynamic>> rows;
      
      if (extension == '.csv') {
        rows = await _parseCsv(file);
      } else if (extension == '.xlsx' || extension == '.xls') {
        rows = await _parseExcel(file);
      } else {
        return ImportResult(
          success: false,
          error: 'Неподдерживаемый формат файла. Используйте CSV или Excel.',
        );
      }

      if (rows.isEmpty) {
        return ImportResult(
          success: false,
          error: 'Файл пуст или не удалось прочитать данные.',
        );
      }

      // Определяем формат файла
      final format = _detectFormat(rows.first);
      
      // Парсим транзакции
      final transactions = <Transaction>[];
      int skippedRows = 0;

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        
        try {
          final tx = _parseTransaction(row, format, i, accountId);
          if (tx != null) {
            transactions.add(tx);
          } else {
            skippedRows++;
          }
        } catch (e) {
          skippedRows++;
        }
      }

      return ImportResult(
        success: true,
        transactions: transactions,
        totalRows: rows.length - 1,
        importedRows: transactions.length,
        skippedRows: skippedRows,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        error: 'Ошибка импорта: $e',
      );
    }
  }

  /// Парсинг CSV файла
  static Future<List<List<dynamic>>> _parseCsv(File file) async {
    final content = await file.readAsString(encoding: const SystemEncoding());
    const csvConverter = CsvToListConverter();
    return csvConverter.convert(content);
  }

  /// Парсинг Excel файла (заглушка - требует дополнительной библиотеки)
  static Future<List<List<dynamic>>> _parseExcel(File file) async {
    // TODO: Реализовать с помощью пакета excel
    // Пока возвращаем заглушку
    return [];
  }

  /// Определение формата выписки
  static BankStatementFormat _detectFormat(List<dynamic> headerRow) {
    final headers = headerRow.map((h) => h.toString().toLowerCase()).toList();

    // Тинькофф
    if (headers.contains('дата') && 
        headers.contains('описание') && 
        (headers.contains('сумма') || headers.contains('amount'))) {
      return BankStatementFormat.tinkoff;
    }

    // Сбербанк
    if (headers.contains('дата') && 
        headers.contains('название') && 
        headers.contains('сумма')) {
      return BankStatementFormat.sber;
    }

    // Альфа-Банк
    if (headers.contains('дата операции') || 
        headers.contains('operation_date')) {
      return BankStatementFormat.alfa;
    }

    // ВТБ
    if (headers.contains('дата') && 
        (headers.contains('тип') || headers.contains('type'))) {
      return BankStatementFormat.vtb;
    }

    // Универсальный формат
    return BankStatementFormat.universal;
  }

  /// Парсинг транзакции из строки
  static Transaction? _parseTransaction(
    List<dynamic> row,
    BankStatementFormat format,
    int rowNum,
    String? accountId,
  ) {
    try {
      DateTime? date;
      double amount = 0;
      String description = '';
      String category = 'Другое';
      String? merchantMcc;

      switch (format) {
        case BankStatementFormat.tinkoff:
          date = _parseDate(row[0]);
          description = row[1]?.toString() ?? '';
          amount = _parseAmount(row[2]);
          category = row.length > 3 ? (row[3]?.toString() ?? 'Другое') : 'Другое';
          break;

        case BankStatementFormat.sber:
          date = _parseDate(row[0]);
          description = row[1]?.toString() ?? '';
          amount = _parseAmount(row[2]);
          category = row.length > 3 ? (row[3]?.toString() ?? 'Другое') : 'Другое';
          merchantMcc = row.length > 4 ? row[4]?.toString() : null;
          break;

        case BankStatementFormat.alfa:
          date = _parseDate(row[0]);
          description = row[1]?.toString() ?? '';
          amount = _parseAmount(row[2]);
          category = row.length > 3 ? (row[3]?.toString() ?? 'Другое') : 'Другое';
          break;

        case BankStatementFormat.vtb:
          date = _parseDate(row[0]);
          description = row[1]?.toString() ?? '';
          amount = _parseAmount(row[2]);
          category = row.length > 3 ? (row[3]?.toString() ?? 'Другое') : 'Другое';
          break;

        case BankStatementFormat.universal:
          // Пытаемся угадать колонки
          for (var cell in row) {
            final str = cell.toString();
            final parsedDate = _parseDate(str);
            if (parsedDate != null && date == null) {
              date = parsedDate;
            } else if (_isNumber(str)) {
              final num = _parseAmount(str);
              if (num.abs() > 0) {
                amount = num;
              }
            } else if (str.length > 3 && description.isEmpty) {
              description = str;
            }
          }
          break;
      }

      if (date == null || amount == 0) {
        return null;
      }

      final type = amount > 0 ? 'income' : 'expense';

      return Transaction(
        id: 'import_${rowNum}_${DateTime.now().millisecondsSinceEpoch}',
        accountId: accountId ?? 'imported',
        amount: amount.abs(),
        category: _mapCategory(category, merchantMcc),
        description: description,
        date: date,
        type: type,
      );
    } catch (e) {
      return null;
    }
  }

  /// Парсинг даты
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    final str = value.toString().trim();

    // Разные форматы дат
    final formats = [
      'dd.MM.yyyy',
      'dd/MM/yyyy',
      'yyyy-MM-dd',
      'dd-MM-yyyy',
      'MM/dd/yyyy',
      'dd.MM.yyyy HH:mm',
      'dd.MM.yy',
    ];

    for (final _ in formats) {
      try {
        return DateTime.parse(str.replaceAll('.', '-').replaceAll('/', '-'));
      } catch (e) {
        continue;
      }
    }

    // Пробуем стандартный парсинг
    try {
      return DateTime.parse(str);
    } catch (e) {
      return null;
    }
  }

  /// Парсинг суммы
  static double _parseAmount(dynamic value) {
    if (value == null) return 0;

    var str = value.toString()
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .replaceAll('₽', '')
        .replaceAll('RUB', '')
        .replaceAll('\$', '')
        .replaceAll('€', '')
        .trim();

    return double.tryParse(str) ?? 0;
  }

  /// Проверка, является ли строка числом
  static bool _isNumber(String str) {
    final cleaned = str
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .replaceAll('₽', '')
        .replaceAll('RUB', '')
        .replaceAll('\$', '')
        .replaceAll('€', '');
    
    return double.tryParse(cleaned) != null;
  }

  /// Маппинг категорий из выписки
  static String _mapCategory(String category, String? mcc) {
    final lowerCategory = category.toLowerCase();

    // По MCC коду
    if (mcc != null) {
      final mccCategory = _getCategoryByMcc(mcc);
      if (mccCategory != 'Другое') return mccCategory;
    }

    // По названию категории
    if (lowerCategory.contains('продукт') || 
        lowerCategory.contains('grocery') ||
        lowerCategory.contains('супермаркет') ||
        lowerCategory.contains('магнит') ||
        lowerCategory.contains('пятёрочк') ||
        lowerCategory.contains('перекрёсток')) {
      return 'Продукты';
    }

    if (lowerCategory.contains('ресторан') ||
        lowerCategory.contains('кафе') ||
        lowerCategory.contains('restaurant') ||
        lowerCategory.contains('мcdonald') ||
        lowerCategory.contains('burger')) {
      return 'Рестораны';
    }

    if (lowerCategory.contains('транспорт') ||
        lowerCategory.contains('метро') ||
        lowerCategory.contains('автобус') ||
        lowerCategory.contains('transport')) {
      return 'Транспорт';
    }

    if (lowerCategory.contains('такси') ||
        lowerCategory.contains('yandex') ||
        lowerCategory.contains('uber') ||
        lowerCategory.contains('ситимобил')) {
      return 'Такси';
    }

    if (lowerCategory.contains('развлечен') ||
        lowerCategory.contains('кино') ||
        lowerCategory.contains('entertainment') ||
        lowerCategory.contains('netflix')) {
      return 'Развлечения';
    }

    if (lowerCategory.contains('здоров') ||
        lowerCategory.contains('аптек') ||
        lowerCategory.contains('медицин') ||
        lowerCategory.contains('health') ||
        lowerCategory.contains('pharmacy')) {
      return 'Здоровье';
    }

    if (lowerCategory.contains('одежд') ||
        lowerCategory.contains('clothing') ||
        lowerCategory.contains('lamoda') ||
        lowerCategory.contains('wildberrie')) {
      return 'Одежда';
    }

    if (lowerCategory.contains('коммунал') ||
        lowerCategory.contains('жилищн') ||
        lowerCategory.contains('utilities')) {
      return 'Коммунальные услуги';
    }

    if (lowerCategory.contains('связ') ||
        lowerCategory.contains('интернет') ||
        lowerCategory.contains('мобильн') ||
        lowerCategory.contains('communication')) {
      return 'Связь';
    }

    if (lowerCategory.contains('зарплат') ||
        lowerCategory.contains('salary') ||
        lowerCategory.contains('зачисление')) {
      return 'Зарплата';
    }

    if (lowerCategory.contains('перевод') ||
        lowerCategory.contains('transfer')) {
      return 'Переводы';
    }

    return 'Другое';
  }

  /// Получение категории по MCC коду
  static String _getCategoryByMcc(String mcc) {
    final mccCode = int.tryParse(mcc);
    if (mccCode == null) return 'Другое';

    if (mccCode >= 5411 && mccCode <= 5499) return 'Продукты';
    if (mccCode >= 5811 && mccCode <= 5814) return 'Рестораны';
    if (mccCode == 4111 || mccCode == 4131) return 'Транспорт';
    if (mccCode == 4121) return 'Такси';
    if (mccCode >= 7922 && mccCode <= 7999) return 'Развлечения';
    if (mccCode >= 5912 && mccCode <= 5913) return 'Здоровье';
    if (mccCode >= 5611 && mccCode <= 5699) return 'Одежда';
    if (mccCode >= 4900 && mccCode <= 4999) return 'Коммунальные услуги';
    if (mccCode == 4899 || mccCode == 4814) return 'Связь';

    return 'Другое';
  }

  /// Получение инструкции по экспорту для банка
  static String getExportInstructions(String bankId) {
    switch (bankId) {
      case 'tinkoff':
        return '''
Инструкция по экспорту из Тинькофф:

1. Откройте приложение Тинькофф
2. Перейдите в раздел "Платежи"
3. Нажмите "Выписки"
4. Выберите период
5. Нажмите "Скачать" → "CSV"
6. Загрузите полученный файл здесь
        ''';
      
      case 'sber':
        return '''
Инструкция по экспорту из Сбербанк:

1. Откройте приложение Сбербанк Онлайн
2. Перейдите в "История операций"
3. Выберите период
4. Нажмите "Экспорт" → "CSV"
5. Загрузите полученный файл здесь
        ''';
      
      case 'alfa':
        return '''
Инструкция по экспорту из Альфа-Банк:

1. Откройте приложение Альфа-Банк
2. Перейдите в "История"
3. Выберите период
4. Нажмите "Экспорт" → "CSV"
5. Загрузите полученный файл здесь
        ''';
      
      case 'vtb':
        return '''
Инструкция по экспорту из ВТБ:

1. Откройте приложение ВТБ Онлайн
2. Перейдите в "Операции"
3. Выберите период
4. Нажмите "Экспорт" → "CSV"
5. Загрузите полученный файл здесь
        ''';
      
      default:
        return 'Экспортируйте выписку из вашего банка в формате CSV и загрузите её здесь.';
    }
  }
}

/// Результат импорта
class ImportResult {
  final bool success;
  final List<Transaction> transactions;
  final String? error;
  final int totalRows;
  final int importedRows;
  final int skippedRows;

  ImportResult({
    required this.success,
    this.transactions = const [],
    this.error,
    this.totalRows = 0,
    this.importedRows = 0,
    this.skippedRows = 0,
  });
}

/// Формат банковской выписки
enum BankStatementFormat {
  tinkoff,
  sber,
  alfa,
  vtb,
  universal,
}
