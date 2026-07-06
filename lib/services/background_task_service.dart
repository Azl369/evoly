import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/services/notification_service.dart';

abstract class BackgroundTaskService {
  Future<void> initialize();

  Future<void> resyncReminders();
}

class NoopBackgroundTaskService implements BackgroundTaskService {
  const NoopBackgroundTaskService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> resyncReminders() async {}
}

/// Android 后台任务服务。
///
/// 通知本身由 flutter_local_notifications 的 zonedSchedule 注册到系统
/// AlarmManager，应用被杀死或设备重启后仍能触发。此服务负责在应用启动时把
/// 数据库中所有未来的有效提醒重新登记到系统调度器，保证 OS 持有完整的待触发列表。
class AndroidBackgroundTaskService implements BackgroundTaskService {
  AndroidBackgroundTaskService({
    required this.reminderRepository,
    required this.taskRepository,
    required this.notificationService,
  });

  final ReminderRepository reminderRepository;
  final TaskRepository taskRepository;
  final NotificationService notificationService;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> resyncReminders() async {
    final now = DateTime.now();
    final reminders = await reminderRepository.findEnabled();

    for (final reminder in reminders) {
      if (reminder.targetType != ReminderTargetType.task) {
        continue;
      }
      if (!reminder.repeatRule.isRepeating && !reminder.remindAt.isAfter(now)) {
        continue;
      }

      final task = await taskRepository.findById(reminder.targetId);
      if (task == null || task.isCompleted) {
        continue;
      }

      await notificationService.schedule(
        id: reminder.id,
        title: 'Evoly 提醒',
        body: task.title,
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
