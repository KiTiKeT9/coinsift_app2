part of 'currency_rate.dart';

class CurrencyRateAdapter extends TypeAdapter<CurrencyRate> {
  @override
  final int typeId = 5;

  @override
  CurrencyRate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CurrencyRate(
      currency: fields[0] as String,
      rate: fields[1] as double,
      baseCurrency: fields[2] as String,
      lastUpdated: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CurrencyRate obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.currency)
      ..writeByte(1)
      ..write(obj.rate)
      ..writeByte(2)
      ..write(obj.baseCurrency)
      ..writeByte(3)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurrencyRateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
