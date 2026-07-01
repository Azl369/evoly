import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/goals/domain/goal.dart';

class GoalMapper {
  static Goal fromMap(Map<String, Object?> map) {
    return Goal(
      id: map['id']! as String,
      title: map['title']! as String,
      description: map['description']! as String,
      type: GoalType.values.byName(map['type']! as String),
      priority: Priority.values.byName(map['priority']! as String),
      status: GoalStatus.values.byName(map['status']! as String),
      startDate: AppDatabaseDateCodec.decodeDate(map['start_date']!),
      dueDate: AppDatabaseDateCodec.decodeNullableDate(map['due_date']),
      progress: (map['progress']! as num).toDouble(),
      createdAt: AppDatabaseDateCodec.decodeDate(map['created_at']!),
      updatedAt: AppDatabaseDateCodec.decodeDate(map['updated_at']!),
    );
  }

  static Map<String, Object?> toMap(Goal goal) {
    return {
      'id': goal.id,
      'title': goal.title,
      'description': goal.description,
      'type': goal.type.name,
      'priority': goal.priority.name,
      'status': goal.status.name,
      'start_date': AppDatabaseDateCodec.encodeDate(goal.startDate),
      'due_date': goal.dueDate == null
          ? null
          : AppDatabaseDateCodec.encodeDate(goal.dueDate!),
      'progress': goal.progress,
      'created_at': AppDatabaseDateCodec.encodeDate(goal.createdAt),
      'updated_at': AppDatabaseDateCodec.encodeDate(goal.updatedAt),
    };
  }
}
