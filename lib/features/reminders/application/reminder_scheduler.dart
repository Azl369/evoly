import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';
import 'package:evoly/services/notification_service.dart';

class ReminderScheduler {
  const ReminderScheduler({
    required this.repository,
    required this.notificationService,
  });

  final ReminderRepository repository;
  final NotificationService notificationService;

  Future<void> schedule(Reminder reminder) async {
    await repository.save(reminder);
    await notificationService.schedule(
      id: reminder.id,
      title: '项目提醒',
      body: '有一个计划需要你推进一下。',
      scheduledAt: reminder.remindAt,
      repeat: _notificationRepeatFor(reminder.repeatRule),
    );
  }

  Future<void> resync(DateTime from, DateTime to) async {
    final reminders = await repository.findUpcoming(from, to);
    for (final reminder in reminders) {
      if (!reminder.enabled) {
        continue;
      }

      await notificationService.schedule(
        id: reminder.id,
        title: '项目提醒',
        body: '有一个计划需要推进。',
        scheduledAt: reminder.remindAt,
        repeat: _notificationRepeatFor(reminder.repeatRule),
      );
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
