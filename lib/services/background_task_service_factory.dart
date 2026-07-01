import 'dart:io';

import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/services/background_task_service.dart';
import 'package:evoly/services/notification_service.dart';

/// 根据当前平台创建合适的后台任务服务实现。
BackgroundTaskService createBackgroundTaskService({
  required ReminderRepository reminderRepository,
  required TaskRepository taskRepository,
  required NotificationService notificationService,
}) {
  if (Platform.isAndroid) {
    return AndroidBackgroundTaskService(
      reminderRepository: reminderRepository,
      taskRepository: taskRepository,
      notificationService: notificationService,
    );
  }
  return const NoopBackgroundTaskService();
}
