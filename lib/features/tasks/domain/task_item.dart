import 'package:evoly/core/domain/priority.dart';

enum TaskStatus {
  pending,
  completed,
  postponed,
  cancelled,
}

enum TaskRepeatRule {
  none,
  weekly,
}

extension TaskRepeatRuleLabel on TaskRepeatRule {
  String get label {
    return switch (this) {
      TaskRepeatRule.none => '不重复',
      TaskRepeatRule.weekly => '每周重复',
    };
  }
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
    this.sortOrder = 0,
    this.estimatedMinutes = 0,
    this.dueDateTime,
    this.completedAt,
    this.repeatRule = TaskRepeatRule.none,
    this.repeatSeriesId,
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
  final TaskRepeatRule repeatRule;
  final String? repeatSeriesId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int sortOrder;

  bool get isCompleted => status == TaskStatus.completed;

  TaskStatus effectiveStatus(DateTime now) {
    final dueDate = dueDateTime;
    if (status == TaskStatus.pending &&
        dueDate != null &&
        dueDate.isBefore(now)) {
      return TaskStatus.postponed;
    }

    return status;
  }

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
    String? goalId,
    String? title,
    String? description,
    Priority? priority,
    TaskStatus? status,
    int? estimatedMinutes,
    DateTime? dueDateTime,
    DateTime? completedAt,
    TaskRepeatRule? repeatRule,
    String? repeatSeriesId,
    DateTime? updatedAt,
    int? sortOrder,
    bool clearDueDateTime = false,
    bool clearCompletedAt = false,
    bool clearRepeatSeriesId = false,
  }) {
    return TaskItem(
      id: id,
      goalId: goalId ?? this.goalId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      dueDateTime: clearDueDateTime ? null : dueDateTime ?? this.dueDateTime,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      repeatRule: repeatRule ?? this.repeatRule,
      repeatSeriesId:
          clearRepeatSeriesId ? null : repeatSeriesId ?? this.repeatSeriesId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
