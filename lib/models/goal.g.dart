part of 'goal.dart';

class GoalAdapter extends TypeAdapter<Goal> {
  @override
  final int typeId = 6;

  @override
  Goal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Goal(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String?,
      targetAmount: fields[3] as double,
      currentAmount: fields[4] as double,
      currency: fields[5] as String,
      createdAt: fields[6] as DateTime,
      deadline: fields[7] as DateTime?,
      iconEmoji: fields[8] as String?,
      category: fields[9] as String?,
      stages: (fields[10] as List?)?.cast<GoalStage>() ?? [],
      notes: (fields[11] as List?)?.cast<GoalNote>() ?? [],
      isCompleted: fields[12] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Goal obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.targetAmount)
      ..writeByte(4)
      ..write(obj.currentAmount)
      ..writeByte(5)
      ..write(obj.currency)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.deadline)
      ..writeByte(8)
      ..write(obj.iconEmoji)
      ..writeByte(9)
      ..write(obj.category)
      ..writeByte(10)
      ..write(obj.stages)
      ..writeByte(11)
      ..write(obj.notes)
      ..writeByte(12)
      ..write(obj.isCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GoalStageAdapter extends TypeAdapter<GoalStage> {
  @override
  final int typeId = 7;

  @override
  GoalStage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GoalStage(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String?,
      targetAmount: fields[3] as double,
      currentAmount: fields[4] as double,
      isCompleted: fields[5] as bool,
      sortOrder: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, GoalStage obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.targetAmount)
      ..writeByte(4)
      ..write(obj.currentAmount)
      ..writeByte(5)
      ..write(obj.isCompleted)
      ..writeByte(6)
      ..write(obj.sortOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalStageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GoalNoteAdapter extends TypeAdapter<GoalNote> {
  @override
  final int typeId = 8;

  @override
  GoalNote read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GoalNote(
      id: fields[0] as String,
      text: fields[1] as String,
      createdAt: fields[2] as DateTime,
      updatedAt: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, GoalNote obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalNoteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
