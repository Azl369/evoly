import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/services/notification_service.dart';

class ReminderInbox {
  const ReminderInbox({
    required this.reminderRepository,
    required this.taskRepository,
    required this.notificationService,
    this.remindersPaused,
  });

  final ReminderRepository reminderRepository;
  final TaskRepository taskRepository;
  final NotificationService notificationService;
  final bool Function(DateTime now)? remindersPaused;

  Future<List<DueReminderMessage>> collectDueMessages(DateTime now) async {
    if (remindersPaused?.call(now) ?? false) {
      return const [];
    }

    final reminders = await reminderRepository.findDue(now);
    final messages = <DueReminderMessage>[];

    for (final reminder in reminders) {
      if (reminder.targetType != ReminderTargetType.task) {
        await reminderRepository.markFired(reminder.id, now);
        continue;
      }

      final task = await taskRepository.findById(reminder.targetId);
      if (task == null || task.isCompleted) {
        await reminderRepository.markFired(reminder.id, now);
        continue;
      }

      var systemNotificationShown = true;
      try {
        await notificationService.showNow(
          id: reminder.id,
          title: 'Evoly 提醒',
          body: task.title,
        );
      } catch (_) {
        systemNotificationShown = false;
      }

      messages.add(
        DueReminderMessage(
          reminderId: reminder.id,
          title: task.title,
          remindAt: reminder.remindAt,
          systemNotificationShown: systemNotificationShown,
        ),
      );
      await _completeDueReminder(reminder, task.title, now);
    }

    return messages;
  }

  Future<void> _completeDueReminder(
    Reminder reminder,
    String notificationBody,
    DateTime now,
  ) async {
    final nextRemindAt = reminder.repeatRule.nextOccurrenceAfter(
      reminder.remindAt,
      now,
    );
    if (nextRemindAt == null) {
      await reminderRepository.markFired(reminder.id, now);
      return;
    }

    final nextReminder = reminder.copyWith(
      remindAt: nextRemindAt,
      updatedAt: now,
      clearFiredAt: true,
    );
    await reminderRepository.save(nextReminder);

    try {
      await notificationService.schedule(
        id: nextReminder.id,
        title: 'Evoly 提醒',
        body: notificationBody,
        scheduledAt: nextReminder.remindAt,
        repeat: _notificationRepeatFor(nextReminder.repeatRule),
      );
    } catch (_) {
      // The database rule has moved forward; notification resync can retry.
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

class DueReminderMessage {
  const DueReminderMessage({
    required this.reminderId,
    required this.title,
    required this.remindAt,
    required this.systemNotificationShown,
  });

  final String reminderId;
  final String title;
  final DateTime remindAt;
  final bool systemNotificationShown;
}
