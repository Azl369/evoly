import 'package:flutter_test/flutter_test.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/reminders/application/reminder_inbox.dart';
import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';
import 'package:evoly/services/notification_service.dart';

void main() {
  test('does not notify or mark reminders fired while paused', () async {
    final now = DateTime(2026, 7, 4, 10);
    final reminderRepository = _FakeReminderRepository([
      _reminder(
          'reminder-1', 'task-1', now.subtract(const Duration(minutes: 5))),
    ]);
    final notificationService = _FakeNotificationService();
    final inbox = ReminderInbox(
      reminderRepository: reminderRepository,
      taskRepository: _FakeTaskRepository([
        _task('task-1', '暂停期间不弹出的任务', now),
      ]),
      notificationService: notificationService,
      remindersPaused: (_) => true,
    );

    final messages = await inbox.collectDueMessages(now);

    expect(messages, isEmpty);
    expect(notificationService.shownIds, isEmpty);
    expect(reminderRepository.firedIds, isEmpty);
  });

  test('moves weekly reminders to the next occurrence after notifying',
      () async {
    final now = DateTime(2026, 7, 8, 9);
    final reminderRepository = _FakeReminderRepository([
      _reminder(
        'weekly-reminder',
        'task-1',
        DateTime(2026, 7, 1, 8),
        repeatRule: RepeatRule.weekly,
      ),
    ]);
    final notificationService = _FakeNotificationService();
    final inbox = ReminderInbox(
      reminderRepository: reminderRepository,
      taskRepository: _FakeTaskRepository([
        _task('task-1', '每周推进一次的任务', now),
      ]),
      notificationService: notificationService,
    );

    final messages = await inbox.collectDueMessages(now);

    expect(messages.single.title, '每周推进一次的任务');
    expect(reminderRepository.firedIds, isEmpty);
    expect(reminderRepository.savedReminders.single.remindAt,
        DateTime(2026, 7, 15, 8));
    expect(
        reminderRepository.savedReminders.single.repeatRule, RepeatRule.weekly);
    expect(
        notificationService.scheduled.single.repeat, NotificationRepeat.weekly);
  });
}

TaskItem _task(String id, String title, DateTime now) {
  return TaskItem(
    id: id,
    goalId: 'goal-1',
    title: title,
    priority: Priority.high,
    status: TaskStatus.pending,
    dueDateTime: now,
    createdAt: now,
    updatedAt: now,
  );
}

Reminder _reminder(
  String id,
  String taskId,
  DateTime remindAt, {
  RepeatRule repeatRule = RepeatRule.none,
}) {
  return Reminder(
    id: id,
    targetType: ReminderTargetType.task,
    targetId: taskId,
    remindAt: remindAt,
    repeatRule: repeatRule,
    enabled: true,
    createdAt: remindAt,
    updatedAt: remindAt,
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
  Future<List<TaskItem>> findPlanningCandidates(DateTime today) async => tasks;

  @override
  Future<List<TaskItem>> findCompletedToday(DateTime today) async =>
      tasks.where((task) => task.status == TaskStatus.completed).toList();

  @override
  Future<void> save(TaskItem task) async {}

  @override
  Future<void> reorderWithinPriority({
    required Priority priority,
    required List<String> orderedTaskIds,
  }) async {}
}

class _FakeReminderRepository implements ReminderRepository {
  _FakeReminderRepository(this.reminders);

  final List<Reminder> reminders;
  final List<String> firedIds = [];
  final List<Reminder> savedReminders = [];

  @override
  Future<void> disable(String id) async {}

  @override
  Future<void> disableForTask(String taskId) async {}

  @override
  Future<Reminder?> findByTaskId(String taskId) async {
    return reminders
        .where((reminder) => reminder.targetId == taskId)
        .firstOrNull;
  }

  @override
  Future<List<Reminder>> findDue(DateTime now) async => reminders;

  @override
  Future<List<Reminder>> findEnabled() async => reminders;

  @override
  Future<List<Reminder>> findUpcoming(DateTime from, DateTime to) async {
    return reminders;
  }

  @override
  Future<void> markFired(String id, DateTime firedAt) async {
    firedIds.add(id);
  }

  @override
  Future<void> save(Reminder reminder) async {
    savedReminders.add(reminder);
    final index = reminders.indexWhere((item) => item.id == reminder.id);
    if (index == -1) {
      reminders.add(reminder);
    } else {
      reminders[index] = reminder;
    }
  }
}

class _FakeNotificationService implements NotificationService {
  final List<String> shownIds = [];
  final List<_ScheduledNotification> scheduled = [];

  @override
  Future<void> cancel(String id) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedule({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    NotificationRepeat repeat = NotificationRepeat.none,
  }) async {
    scheduled.add(
      _ScheduledNotification(
        repeat: repeat,
      ),
    );
  }

  @override
  Future<void> showNow({
    required String id,
    required String title,
    required String body,
  }) async {
    shownIds.add(id);
  }
}

class _ScheduledNotification {
  const _ScheduledNotification({
    required this.repeat,
  });

  final NotificationRepeat repeat;
}
