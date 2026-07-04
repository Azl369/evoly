import 'package:evoly/core/domain/priority.dart';

class CompactReminderSnapshot {
  const CompactReminderSnapshot({
    required this.generatedAt,
    required this.highPriorityTasks,
    required this.pendingCount,
    required this.overdueCount,
    required this.completedCount,
    this.nextReminder,
  });

  final DateTime generatedAt;
  final CompactReminderItem? nextReminder;
  final List<CompactTaskItem> highPriorityTasks;
  final int pendingCount;
  final int overdueCount;
  final int completedCount;

  bool get hasPendingTasks => pendingCount > 0;
}

class CompactReminderItem {
  const CompactReminderItem({
    required this.taskId,
    required this.title,
    required this.remindAt,
    required this.priority,
  });

  final String taskId;
  final String title;
  final DateTime remindAt;
  final Priority priority;
}

class CompactTaskItem {
  const CompactTaskItem({
    required this.id,
    required this.title,
    required this.priority,
    required this.estimatedMinutes,
    this.dueDateTime,
  });

  final String id;
  final String title;
  final Priority priority;
  final int estimatedMinutes;
  final DateTime? dueDateTime;
}
