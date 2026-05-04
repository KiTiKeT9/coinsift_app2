import 'package:coinsift_app/models/transaction.dart';
import 'package:coinsift_app/services/transaction_deduplicator.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _tx({
  required String id,
  required double amount,
  required String type,
  required DateTime date,
  String? bankId,
  String? merchant,
  String? cardMask,
  String? source,
  bool isDraft = false,
}) {
  final fp = TransactionFingerprint.compute(
    date: date,
    amountSigned: type == 'income' ? amount : -amount,
    bankId: bankId,
    merchant: merchant,
    cardMask: cardMask,
  );
  return Transaction(
    id: id,
    accountId: 'acc-1',
    amount: amount,
    type: type,
    category: 'Другое',
    date: date,
    merchantName: merchant,
    source: source,
    bankId: bankId,
    externalId: fp,
    cardMask: cardMask,
    isDraft: isDraft,
  );
}

void main() {
  group('TransactionDeduplicator', () {
    final dedup = TransactionDeduplicator();

    test('находит точный дубль по fingerprint', () {
      final date = DateTime(2026, 5, 2, 19, 32);
      final existing = _tx(
        id: 'a',
        amount: 1234.56,
        type: 'expense',
        date: date,
        bankId: 'sber',
        merchant: 'MAGNIT',
        cardMask: '1234',
      );
      final incoming = _tx(
        id: 'b',
        amount: 1234.56,
        type: 'expense',
        date: date,
        bankId: 'sber',
        merchant: 'MAGNIT',
        cardMask: '1234',
      );
      expect(dedup.findDuplicate(incoming, [existing]), isNotNull);
    });

    test('fuzzy-сливает SMS-черновик и последующий импорт выписки', () {
      final smsDate = DateTime(2026, 5, 2, 19, 32);
      final draft = _tx(
        id: 'draft',
        amount: 1500,
        type: 'expense',
        date: smsDate,
        bankId: 'tinkoff',
        merchant: 'SAMOKAT',
        cardMask: '1234',
        source: TransactionSource.sms,
        isDraft: true,
      );
      final imported = _tx(
        id: 'imp',
        amount: 1500,
        type: 'expense',
        // Выписка часто приходит с датой проводки на сутки позже.
        date: smsDate.add(const Duration(hours: 20)),
        bankId: 'tinkoff',
        merchant: 'SAMOKAT',
        cardMask: '1234',
        source: TransactionSource.statementImport,
      );
      final match = dedup.findDuplicate(imported, [draft]);
      expect(match, same(draft));

      dedup.mergeInto(draft, imported);
      expect(draft.isDraft, isFalse, reason: 'Импорт подтверждает черновик');
      expect(draft.source, TransactionSource.statementImport,
          reason: 'Источник повышается до более авторитетного');
    });

    test('разные суммы — не дубли', () {
      final date = DateTime(2026, 5, 2, 19, 32);
      final a = _tx(
        id: 'a',
        amount: 100,
        type: 'expense',
        date: date,
        bankId: 'sber',
      );
      final b = _tx(
        id: 'b',
        amount: 101,
        type: 'expense',
        date: date,
        bankId: 'sber',
      );
      expect(dedup.findDuplicate(b, [a]), isNull);
    });

    test('разные знаки (income vs expense) — не дубли', () {
      final date = DateTime(2026, 5, 2, 19, 32);
      final spent = _tx(
        id: 'spent',
        amount: 500,
        type: 'expense',
        date: date,
        bankId: 'sber',
      );
      final received = _tx(
        id: 'rcv',
        amount: 500,
        type: 'income',
        date: date,
        bankId: 'sber',
      );
      expect(dedup.findDuplicate(received, [spent]), isNull);
    });

    test('за пределами fuzzy-окна — не дубли', () {
      final a = _tx(
        id: 'a',
        amount: 100,
        type: 'expense',
        date: DateTime(2026, 5, 1, 10, 0),
        bankId: 'sber',
        source: TransactionSource.sms,
      );
      final b = _tx(
        id: 'b',
        amount: 100,
        type: 'expense',
        date: DateTime(2026, 5, 5, 10, 0),
        bankId: 'sber',
        source: TransactionSource.statementImport,
      );
      expect(dedup.findDuplicate(b, [a]), isNull);
    });

    test('одинаковая сумма и время, но разные merchant — не дубли', () {
      final date = DateTime(2026, 5, 2, 19, 32);
      final a = _tx(
        id: 'a',
        amount: 250,
        type: 'expense',
        date: date,
        bankId: 'tinkoff',
        merchant: 'STARBUCKS',
      );
      final b = _tx(
        id: 'b',
        amount: 250,
        type: 'expense',
        date: date.add(const Duration(minutes: 1)),
        bankId: 'tinkoff',
        merchant: 'MCDONALDS',
      );
      expect(dedup.findDuplicate(b, [a]), isNull);
    });
  });

  group('TransactionFingerprint', () {
    test('стабилен для той же операции', () {
      final date = DateTime(2026, 5, 2, 19, 32, 15);
      final fp1 = TransactionFingerprint.compute(
        date: date,
        amountSigned: -1500,
        bankId: 'sber',
        merchant: 'Pyaterochka 1234',
      );
      final fp2 = TransactionFingerprint.compute(
        date: date.add(const Duration(seconds: 44)), // та же минута
        amountSigned: -1500.00,
        bankId: 'sber',
        merchant: 'pyaterochka 1234!',
      );
      expect(fp1, fp2);
    });

    test('меняется от суммы', () {
      final date = DateTime(2026, 5, 2, 19, 32);
      final fp1 = TransactionFingerprint.compute(
        date: date,
        amountSigned: -1500,
        bankId: 'sber',
      );
      final fp2 = TransactionFingerprint.compute(
        date: date,
        amountSigned: -1501,
        bankId: 'sber',
      );
      expect(fp1, isNot(fp2));
    });
  });
}
