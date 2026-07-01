import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/reminders/data/sqlite_reminder_repository.dart';
import 'package:evoly/features/tasks/data/sqlite_task_repository.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/services/background_task_service.dart';
import 'package:evoly/services/background_task_service_factory.dart';
import 'package:evoly/services/notification_service.dart';
import 'package:evoly/services/notification_service_factory.dart';

class AppLifecycleCoordinator {
  AppLifecycleCoordinator({
    AppDatabase? database,
    NotificationService? notificationService,
    BackgroundTaskService? backgroundTaskService,
  })  : database = database ?? AppDatabase.instance,
        notificationService =
            notificationService ?? createNotificationService(),
        _backgroundTaskService = backgroundTaskService;

  final AppDatabase database;
  final NotificationService notificationService;
  BackgroundTaskService? _backgroundTaskService;

  Future<void> bootstrap() async {
    await database.open();
    await notificationService.initialize();

    final ReminderRepository reminderRepository =
        SqliteReminderRepository(database);
    final TaskRepository taskRepository = SqliteTaskRepository(database);
    final backgroundTaskService =
        _backgroundTaskService ??= createBackgroundTaskService(
      reminderRepository: reminderRepository,
      taskRepository: taskRepository,
      notificationService: notificationService,
    );
    await backgroundTaskService.initialize();
    await backgroundTaskService.resyncReminders();
  }

  Future<void> shutdown() async {
    await database.close();
  }
}
