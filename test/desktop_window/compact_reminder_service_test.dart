import 'package:flutter_test/flutter_test.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/desktop_window/application/compact_reminder_service.dart';
import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

void main() {
  test('builds next reminder, high priority top 3, and counts', () async {
    final now = DateTime(2026, 7, 4, 10);
    final tasks = [
      _task('low', '低优先级', Priority.low, now.add(const Duration(hours: 4))),
      _task(
          'high-1', '高优先级 1', Priority.high, now.add(const Duration(hours: 3))),
      _task('done', '已完成', Priority.high, now.add(const Duration(hours: 1)),
          status: TaskStatus.completed),
      _task(
          'medium', '中优先级', Priority.medium, now.add(const Duration(hours: 2))),
      _task('high-2', '高优先级 2', Priority.high,
          now.subtract(const Duration(hours: 1))),
      _task(
          'high-3', '高优先级 3', Priority.high, now.add(const Duration(hours: 5))),
    ];
    final reminders = [
      _reminder('done-reminder', 'done', now.add(const Duration(minutes: 5))),
      _reminder('next', 'medium', now.add(const Duration(minutes: 15))),
      _reminder('later', 'high-1', now.add(const Duration(minutes: 30))),
    ];
    final service = CompactReminderService(
      taskRepository: _FakeTaskRepository(tasks),
      reminderRepository: _FakeReminderRepository(reminders),
    );

    final snapshot = await service.loadSnapshot(now);

    expect(snapshot.nextReminder?.taskId, 'medium');
    expect(snapshot.highPriorityTasks.map((task) => task.id), [
      'high-2',
      'high-1',
      'high-3',
    ]);
    expect(snapshot.pendingCount, 5);
    expect(snapshot.completedCount, 1);
    expect(snapshot.overdueCount, 1);
  });
}

TaskItem _task(
  String id,
  String title,
  Priority priority,
  DateTime dueDateTime, {
  TaskStatus status = TaskStatus.pending,
}) {
  final now = DateTime(2026, 7, 4, 9);
  return TaskItem(
    id: id,
    goalId: 'goal-1',
    title: title,
    priority: priority,
    status: status,
    estimatedMinutes: 20,
    dueDateTime: dueDateTime,
    completedAt: status == TaskStatus.completed ? now : null,
    createdAt: now,
    updatedAt: now,
  );
}

Reminder _reminder(String id, String taskId, DateTime remindAt) {
  final now = DateTime(2026, 7, 4, 9);
  return Reminder(
    id: id,
    targetType: ReminderTargetType.task,
    targetId: taskId,
    remindAt: remindAt,
    repeatRule: RepeatRule.none,
    enabled: true,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeTaskRepository implements TaskRepository {
  const _FakeTaskRepository(this.tasks);

  final List<TaskItem> tasks;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<TaskItem?> findById(String id) async {
    return tasks.where((task) => task.id == id).firstOrNull;
  }

  @override
  Future<List<TaskItem>> findByGoalId(String goalId) async {
    return tasks.where((task) => task.goalId == goalId).toList();
  }

  @override
  Future<List<TaskItem>> findDueToday(DateTime today) async => tasks;

  @override
  Future<void> save(TaskItem task) async {}
}

class _FakeReminderRepository implements ReminderRepository {
  const _FakeReminderRepository(this.reminders);

  final List<Reminder> reminders;

  @override
  Future<void> disable(String id) async {}

  @override
  Future<void> disableForTask(String taskId) async {}

  @override
  Future<Reminder?> findByTaskId(String taskId) async => null;

  @override
  Future<List<Reminder>> findDue(DateTime now) async => const [];

  @override
  Future<List<Reminder>> findEnabled() async => reminders;

  @override
  Future<List<Reminder>> findUpcoming(DateTime from, DateTime to) async {
    return reminders;
  }

  @override
  Future<void> markFired(String id, DateTime firedAt) async {}

  @override
  Future<void> save(Reminder reminder) async {}
}
