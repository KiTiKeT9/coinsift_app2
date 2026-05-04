import 'package:coinsift_app/services/sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SmsBankParser — Сбер', () {
    test('списание', () {
      final r = SmsBankParser.parse(
        'MIR-1234 02.05.26 19:32 Pokupka 1 234.56 RUB MAGNIT Balans: 12 345.67 RUB',
        sender: '900',
      );
      expect(r, isNotNull);
      expect(r!.bankId, 'sber');
      expect(r.type, 'expense');
      expect(r.amount, closeTo(1234.56, 0.001));
      expect(r.cardMask, '1234');
      expect(r.date.year, 2026);
      expect(r.date.month, 5);
      expect(r.date.day, 2);
    });

    test('зачисление', () {
      final r = SmsBankParser.parse(
        'ECMC1234 03.05.26 12:00 Zachislenie 5000.00 RUB Perevod ot IVAN I.',
        sender: 'SBERBANK',
      );
      expect(r, isNotNull);
      expect(r!.type, 'income');
      expect(r.amount, 5000.0);
    });
  });

  group('SmsBankParser — Тинькофф', () {
    test('покупка', () {
      final r = SmsBankParser.parse(
        'Pokupka. Karta *1234. Summa 1234.56 RUB. ALFA-COFFEE. Dostupno 9876.54 RUB',
        sender: 'Tinkoff',
      );
      expect(r, isNotNull);
      expect(r!.bankId, 'tinkoff');
      expect(r.type, 'expense');
      expect(r.amount, 1234.56);
      expect(r.cardMask, '1234');
    });

    test('пополнение в рублях со значком ₽', () {
      final r = SmsBankParser.parse(
        'Пополнение. Карта *5678. Сумма 250 ₽. Доступно 12 345 ₽',
        sender: 'T-Bank',
      );
      expect(r, isNotNull);
      expect(r!.type, 'income');
      expect(r.amount, 250.0);
      expect(r.cardMask, '5678');
    });
  });

  group('SmsBankParser — игнорируем не-транзакции', () {
    test('SMS с кодом подтверждения не парсится', () {
      final r = SmsBankParser.parse(
        'Никому не сообщайте код 1234',
        sender: '900',
      );
      expect(r, isNull);
    });
  });
}
