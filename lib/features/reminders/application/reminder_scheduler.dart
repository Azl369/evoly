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
      title: '目标提醒',
      body: '有一个计划需要你推进一下。',
      scheduledAt: reminder.remindAt,
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
        title: '目标提醒',
        body: '别忘了今天的小目标。',
        scheduledAt: reminder.remindAt,
      );
    }
  }
}
