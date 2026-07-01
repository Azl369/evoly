import 'package:evoly/core/domain/priority.dart';

enum TaskStatus {
  pending,
  completed,
  postponed,
  cancelled,
}

extension TaskStatusLabel on TaskStatus {
  String get label {
    return switch (this) {
      TaskStatus.pending => '待完成',
      TaskStatus.completed => '已完成',
      TaskStatus.postponed => '已延期',
      TaskStatus.cancelled => '已取消',
    };
  }
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.goalId,
    required this.title,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.estimatedMinutes = 0,
    this.dueDateTime,
    this.completedAt,
  });

  final String id;
  final String goalId;
  final String title;
  final String description;
  final Priority priority;
  final TaskStatus status;
  final int estimatedMinutes;
  final DateTime? dueDateTime;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => status == TaskStatus.completed;

  bool isDueToday(DateTime now) {
    final dueDate = dueDateTime;
    if (dueDate == null) {
      return false;
    }

    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  TaskItem copyWith({
    String? title,
    String? description,
    Priority? priority,
    TaskStatus? status,
    int? estimatedMinutes,
    DateTime? dueDateTime,
    DateTime? completedAt,
    DateTime? updatedAt,
    bool clearDueDateTime = false,
    bool clearCompletedAt = false,
  }) {
    return TaskItem(
      id: id,
      goalId: goalId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      dueDateTime: clearDueDateTime ? null : dueDateTime ?? this.dueDateTime,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
