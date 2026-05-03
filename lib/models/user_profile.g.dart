// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 2;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      id: fields[0] as String,
      name: fields[1] as String,
      email: fields[2] as String,
      birthDate: fields[3] as DateTime?,
      avatarPath: fields[4] as String?,
      currency: fields[5] as String,
      monthlyBudget: fields[6] as double,
      notificationSettings: (fields[7] as List).cast<String>(),
      darkTheme: fields[8] as bool,
      language: fields[9] as String,
      enablePinLock: fields[10] as bool,
      customBackgroundPath: fields[11] as String?,
      useCustomBackground: fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.birthDate)
      ..writeByte(4)
      ..write(obj.avatarPath)
      ..writeByte(5)
      ..write(obj.currency)
      ..writeByte(6)
      ..write(obj.monthlyBudget)
      ..writeByte(7)
      ..write(obj.notificationSettings)
      ..writeByte(8)
      ..write(obj.darkTheme)
      ..writeByte(9)
      ..write(obj.language)
      ..writeByte(10)
      ..write(obj.enablePinLock)
      ..writeByte(11)
      ..write(obj.customBackgroundPath)
      ..writeByte(12)
      ..write(obj.useCustomBackground);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
