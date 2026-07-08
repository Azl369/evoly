import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

class TaskMapper {
  static TaskItem fromMap(Map<String, Object?> map) {
    return TaskItem(
      id: map['id']! as String,
      goalId: map['goal_id']! as String,
      title: map['title']! as String,
      description: map['description']! as String,
      priority: Priority.values.byName(map['priority']! as String),
      status: TaskStatus.values.byName(map['status']! as String),
      estimatedMinutes: map['estimated_minutes']! as int,
      dueDateTime:
          AppDatabaseDateCodec.decodeNullableDate(map['due_date_time']),
      completedAt: AppDatabaseDateCodec.decodeNullableDate(map['completed_at']),
      createdAt: AppDatabaseDateCodec.decodeDate(map['created_at']!),
      updatedAt: AppDatabaseDateCodec.decodeDate(map['updated_at']!),
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  static Map<String, Object?> toMap(TaskItem task) {
    return {
      'id': task.id,
      'goal_id': task.goalId,
      'title': task.title,
      'description': task.description,
      'priority': task.priority.name,
      'status': task.status.name,
      'estimated_minutes': task.estimatedMinutes,
      'due_date_time': task.dueDateTime == null
          ? null
          : AppDatabaseDateCodec.encodeDate(task.dueDateTime!),
      'completed_at': task.completedAt == null
          ? null
          : AppDatabaseDateCodec.encodeDate(task.completedAt!),
      'created_at': AppDatabaseDateCodec.encodeDate(task.createdAt),
      'updated_at': AppDatabaseDateCodec.encodeDate(task.updatedAt),
      'sort_order': task.sortOrder,
    };
  }
}
