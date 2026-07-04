import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/desktop_window/domain/compact_reminder_snapshot.dart';
import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

class CompactReminderService {
  const CompactReminderService({
    required this.taskRepository,
    required this.reminderRepository,
  });

  final TaskRepository taskRepository;
  final ReminderRepository reminderRepository;

  Future<CompactReminderSnapshot> loadSnapshot(DateTime now) async {
    final results = await Future.wait([
      taskRepository.findDueToday(now),
      reminderRepository.findUpcoming(now, _endOfDay(now)),
    ]);
    final tasks = results[0] as List<TaskItem>;
    final reminders = (results[1] as List<Reminder>)
        .where((reminder) => reminder.targetType == ReminderTargetType.task)
        .toList()
      ..sort((left, right) => left.remindAt.compareTo(right.remindAt));

    final pendingTasks = tasks.where((task) => !task.isCompleted).toList();
    final taskById = {for (final task in tasks) task.id: task};
    final nextReminder = _findNextReminder(reminders, taskById);
    final highPriorityTasks = [...pendingTasks]..sort((left, right) {
        final priorityCompare =
            right.priority.weight.compareTo(left.priority.weight);
        if (priorityCompare != 0) {
          return priorityCompare;
        }

        return _compareNullableDate(left.dueDateTime, right.dueDateTime);
      });

    return CompactReminderSnapshot(
      generatedAt: now,
      nextReminder: nextReminder,
      highPriorityTasks: highPriorityTasks
          .take(3)
          .map(
            (task) => CompactTaskItem(
              id: task.id,
              title: task.title,
              priority: task.priority,
              estimatedMinutes: task.estimatedMinutes,
              dueDateTime: task.dueDateTime,
            ),
          )
          .toList(),
      pendingCount: pendingTasks.length,
      overdueCount: pendingTasks
          .where((task) => task.dueDateTime?.isBefore(now) ?? false)
          .length,
      completedCount: tasks.length - pendingTasks.length,
    );
  }

  CompactReminderItem? _findNextReminder(
    List<Reminder> reminders,
    Map<String, TaskItem> taskById,
  ) {
    for (final reminder in reminders) {
      final task = taskById[reminder.targetId];
      if (task == null || task.isCompleted) {
        continue;
      }

      return CompactReminderItem(
        taskId: task.id,
        title: task.title,
        remindAt: reminder.remindAt,
        priority: task.priority,
      );
    }

    return null;
  }

  DateTime _endOfDay(DateTime now) {
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  int _compareNullableDate(DateTime? left, DateTime? right) {
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }

    return left.compareTo(right);
  }
}
