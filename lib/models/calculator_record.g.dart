// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calculator_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CalculatorRecordAdapter extends TypeAdapter<CalculatorRecord> {
  @override
  final int typeId = 4;

  @override
  CalculatorRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CalculatorRecord(
      id: fields[0] as String,
      type: fields[1] as String,
      bankName: fields[2] as String,
      amount: fields[3] as double,
      interestRate: fields[4] as double,
      termMonths: fields[5] as int,
      calculationDate: fields[6] as DateTime,
      monthlyPayment: fields[7] as double,
      totalPayment: fields[8] as double,
      totalInterest: fields[9] as double,
      additionalData: (fields[10] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, CalculatorRecord obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.bankName)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.interestRate)
      ..writeByte(5)
      ..write(obj.termMonths)
      ..writeByte(6)
      ..write(obj.calculationDate)
      ..writeByte(7)
      ..write(obj.monthlyPayment)
      ..writeByte(8)
      ..write(obj.totalPayment)
      ..writeByte(9)
      ..write(obj.totalInterest)
      ..writeByte(10)
      ..write(obj.additionalData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalculatorRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
