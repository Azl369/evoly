import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';
import 'package:evoly/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class TaskReminderService {
  const TaskReminderService(
    this.repository, {
    this.notificationService,
  });

  final ReminderRepository repository;
  final NotificationService? notificationService;

  Future<Reminder?> findForTask(String taskId) {
    return repository.findByTaskId(taskId);
  }

  Future<Reminder?> saveForTask({
    required String taskId,
    required DateTime? remindAt,
    RepeatRule repeatRule = RepeatRule.none,
    String? notificationBody,
  }) async {
    final existingReminder = await repository.findByTaskId(taskId);
    await _cancelExisting(existingReminder);
    await repository.disableForTask(taskId);

    if (remindAt == null) {
      return null;
    }

    final now = DateTime.now();
    const uuid = Uuid();
    final reminder = Reminder(
      id: uuid.v4(),
      targetType: ReminderTargetType.task,
      targetId: taskId,
      remindAt: remindAt,
      repeatRule: repeatRule,
      enabled: true,
      createdAt: now,
      updatedAt: now,
    );
    await repository.save(reminder);
    await _schedule(reminder, notificationBody);
    return reminder;
  }

  Future<void> _cancelExisting(Reminder? reminder) async {
    if (reminder == null) {
      return;
    }

    try {
      await notificationService?.cancel(reminder.id);
    } catch (_) {
      // A failed OS cancellation should not prevent the database update.
    }
  }

  Future<void> _schedule(Reminder reminder, String? notificationBody) async {
    if (notificationBody == null) {
      return;
    }

    try {
      await notificationService?.schedule(
        id: reminder.id,
        title: 'Evoly 提醒',
        body: notificationBody,
        scheduledAt: reminder.remindAt,
        repeat: _notificationRepeatFor(reminder.repeatRule),
      );
    } catch (_) {
      // The saved reminder can still be registered during the next resync.
    }
  }

  NotificationRepeat _notificationRepeatFor(RepeatRule repeatRule) {
    return switch (repeatRule) {
      RepeatRule.daily => NotificationRepeat.daily,
      RepeatRule.weekly => NotificationRepeat.weekly,
      RepeatRule.monthly => NotificationRepeat.monthly,
      RepeatRule.none || RepeatRule.custom => NotificationRepeat.none,
    };
  }
}
