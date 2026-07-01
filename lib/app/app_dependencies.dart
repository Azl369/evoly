import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/features/coach/application/rule_based_coach_service.dart';
import 'package:evoly/features/coach/data/coach_repository.dart';
import 'package:evoly/features/coach/data/sqlite_coach_repository.dart';
import 'package:evoly/features/documents/data/document_repository.dart';
import 'package:evoly/features/documents/data/sqlite_document_repository.dart';
import 'package:evoly/features/goals/data/goal_repository.dart';
import 'package:evoly/features/goals/data/sqlite_goal_repository.dart';
import 'package:evoly/features/reminders/application/reminder_inbox.dart';
import 'package:evoly/features/reminders/application/task_reminder_service.dart';
import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/reminders/data/sqlite_reminder_repository.dart';
import 'package:evoly/features/stats/data/sqlite_stats_repository.dart';
import 'package:evoly/features/stats/data/stats_repository.dart';
import 'package:evoly/features/tasks/data/sqlite_task_repository.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/services/background_task_service.dart';
import 'package:evoly/services/background_task_service_factory.dart';
import 'package:evoly/services/notification_service.dart';
import 'package:evoly/services/notification_service_factory.dart';

class AppDependencies extends StatelessWidget {
  const AppDependencies({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: AppDatabase.instance),
        Provider<NotificationService>(
          create: (_) => createNotificationService(),
        ),
        Provider<GoalRepository>(
          create: (context) =>
              SqliteGoalRepository(context.read<AppDatabase>()),
        ),
        Provider<TaskRepository>(
          create: (context) =>
              SqliteTaskRepository(context.read<AppDatabase>()),
        ),
        Provider<DocumentRepository>(
          create: (context) =>
              SqliteDocumentRepository(context.read<AppDatabase>()),
        ),
        Provider<CoachRepository>(
          create: (context) =>
              SqliteCoachRepository(context.read<AppDatabase>()),
        ),
        Provider<RuleBasedCoachService>(
          create: (context) =>
              RuleBasedCoachService(context.read<CoachRepository>()),
        ),
        Provider<ReminderRepository>(
          create: (context) =>
              SqliteReminderRepository(context.read<AppDatabase>()),
        ),
        Provider<ReminderInbox>(
          create: (context) => ReminderInbox(
            reminderRepository: context.read<ReminderRepository>(),
            taskRepository: context.read<TaskRepository>(),
            notificationService: context.read<NotificationService>(),
          ),
        ),
        Provider<TaskReminderService>(
          create: (context) =>
              TaskReminderService(context.read<ReminderRepository>()),
        ),
        Provider<BackgroundTaskService>(
          create: (context) => createBackgroundTaskService(
            reminderRepository: context.read<ReminderRepository>(),
            taskRepository: context.read<TaskRepository>(),
            notificationService: context.read<NotificationService>(),
          ),
        ),
        Provider<StatsRepository>(
          create: (context) =>
              SqliteStatsRepository(context.read<AppDatabase>()),
        ),
      ],
      child: child,
    );
  }
}
