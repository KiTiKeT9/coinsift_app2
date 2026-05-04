// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 1;

  @override
  Transaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transaction(
      id: fields[0] as String,
      accountId: fields[1] as String,
      amount: fields[2] as double,
      type: fields[3] as String,
      category: fields[4] as String,
      description: fields[5] as String,
      date: fields[6] as DateTime,
      currency: fields[7] as String,
      merchantName: fields[8] as String?,
      tags: (fields[9] as List).cast<String>(),
      isRecurring: fields[10] as bool,
      recurringPeriod: fields[11] as String?,
      source: fields[12] as String?,
      externalId: fields[13] as String?,
      bankId: fields[14] as String?,
      isDraft: (fields[15] as bool?) ?? false,
      cardMask: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.accountId)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.currency)
      ..writeByte(8)
      ..write(obj.merchantName)
      ..writeByte(9)
      ..write(obj.tags)
      ..writeByte(10)
      ..write(obj.isRecurring)
      ..writeByte(11)
      ..write(obj.recurringPeriod)
      ..writeByte(12)
      ..write(obj.source)
      ..writeByte(13)
      ..write(obj.externalId)
      ..writeByte(14)
      ..write(obj.bankId)
      ..writeByte(15)
      ..write(obj.isDraft)
      ..writeByte(16)
      ..write(obj.cardMask);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
