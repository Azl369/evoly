import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';

class ReminderMapper {
  static Reminder fromMap(Map<String, Object?> map) {
    return Reminder(
      id: map['id']! as String,
      targetType: ReminderTargetType.values.byName(
        map['target_type']! as String,
      ),
      targetId: map['target_id']! as String,
      remindAt: AppDatabaseDateCodec.decodeDate(map['remind_at']!),
      repeatRule: RepeatRule.values.byName(map['repeat_rule']! as String),
      advanceMinutes: (map['advance_minutes'] as num?)?.toInt() ?? 0,
      enabled: map['enabled'] == 1,
      firedAt: AppDatabaseDateCodec.decodeNullableDate(map['fired_at']),
      createdAt: AppDatabaseDateCodec.decodeDate(map['created_at']!),
      updatedAt: AppDatabaseDateCodec.decodeDate(map['updated_at']!),
    );
  }

  static Map<String, Object?> toMap(Reminder reminder) {
    return {
      'id': reminder.id,
      'target_type': reminder.targetType.name,
      'target_id': reminder.targetId,
      'remind_at': AppDatabaseDateCodec.encodeDate(reminder.remindAt),
      'repeat_rule': reminder.repeatRule.name,
      'advance_minutes': reminder.advanceMinutes,
      'enabled': reminder.enabled ? 1 : 0,
      'fired_at': reminder.firedAt == null
          ? null
          : AppDatabaseDateCodec.encodeDate(reminder.firedAt!),
      'created_at': AppDatabaseDateCodec.encodeDate(reminder.createdAt),
      'updated_at': AppDatabaseDateCodec.encodeDate(reminder.updatedAt),
    };
  }
}
