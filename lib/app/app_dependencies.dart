import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/data_refresh_controller.dart';
import 'package:evoly/app/supabase_bootstrap.dart';
import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/features/coach/application/rule_based_coach_service.dart';
import 'package:evoly/features/coach/data/coach_repository.dart';
import 'package:evoly/features/coach/data/sqlite_coach_repository.dart';
import 'package:evoly/features/desktop_window/application/compact_reminder_service.dart';
import 'package:evoly/features/desktop_window/application/desktop_window_controller.dart';
import 'package:evoly/features/documents/data/document_repository.dart';
import 'package:evoly/features/documents/data/sqlite_document_repository.dart';
import 'package:evoly/features/goals/data/goal_repository.dart';
import 'package:evoly/features/goals/data/sqlite_goal_repository.dart';
import 'package:evoly/features/reminders/application/reminder_inbox.dart';
import 'package:evoly/features/reminders/application/task_reminder_service.dart';
import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/reminders/data/sqlite_reminder_repository.dart';
import 'package:evoly/features/settings/application/settings_controller.dart';
import 'package:evoly/features/settings/data/settings_repository.dart';
import 'package:evoly/features/settings/data/sqlite_settings_repository.dart';
import 'package:evoly/features/stats/data/sqlite_stats_repository.dart';
import 'package:evoly/features/stats/data/stats_repository.dart';
import 'package:evoly/features/sync/application/sqlite_remote_change_applier.dart';
import 'package:evoly/features/sync/application/supabase_auth_controller.dart';
import 'package:evoly/features/sync/application/sync_change_recorder.dart';
import 'package:evoly/features/sync/application/sync_coordinator.dart';
import 'package:evoly/features/sync/application/sync_engine.dart';
import 'package:evoly/features/sync/application/sync_initial_snapshot_queue.dart';
import 'package:evoly/features/sync/data/fake_remote_sync_repository.dart';
import 'package:evoly/features/sync/data/remote_sync_repository.dart';
import 'package:evoly/features/sync/data/supabase_remote_sync_repository.dart';
import 'package:evoly/features/sync/data/sqlite_sync_outbox_repository.dart';
import 'package:evoly/features/sync/data/sqlite_sync_state_repository.dart';
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
        ChangeNotifierProvider<DataRefreshController>(
          create: (_) => DataRefreshController(),
        ),
        Provider<NotificationService>(
          create: (_) => createNotificationService(),
        ),
        Provider<SettingsRepository>(
          create: (context) =>
              SqliteSettingsRepository(context.read<AppDatabase>()),
        ),
        ChangeNotifierProvider<SettingsController>(
          create: (context) =>
              SettingsController(context.read<SettingsRepository>())..load(),
        ),
        Provider<SqliteSyncStateRepository>(
          create: (context) =>
              SqliteSyncStateRepository(context.read<AppDatabase>()),
        ),
        Provider<SyncChangeRecorder>(
          create: (context) => SyncChangeRecorder(context.read<AppDatabase>()),
        ),
        Provider<SqliteSyncOutboxRepository>(
          create: (context) =>
              SqliteSyncOutboxRepository(context.read<AppDatabase>()),
        ),
        Provider<SyncInitialSnapshotQueue>(
          create: (context) => SyncInitialSnapshotQueue(
            database: context.read<AppDatabase>(),
            changeRecorder: context.read<SyncChangeRecorder>(),
            syncStateRepository: context.read<SqliteSyncStateRepository>(),
          ),
        ),
        Provider<RemoteSyncRepository>(
          create: (_) {
            final client = SupabaseBootstrap.clientOrNull;
            if (client == null) {
              return FakeRemoteSyncRepository();
            }

            return SupabaseRemoteSyncRepository(client);
          },
        ),
        Provider<SqliteRemoteChangeApplier>(
          create: (context) =>
              SqliteRemoteChangeApplier(context.read<AppDatabase>()),
        ),
        Provider<SyncEngine>(
          create: (context) => SyncEngine(
            outboxRepository: context.read<SqliteSyncOutboxRepository>(),
            remoteRepository: context.read<RemoteSyncRepository>(),
            remoteChangeApplier: context.read<SqliteRemoteChangeApplier>(),
            syncStateRepository: context.read<SqliteSyncStateRepository>(),
          ),
        ),
        Provider<SyncCoordinator>(
          create: (context) => SyncCoordinator(
            syncEngine: context.read<SyncEngine>(),
            dataRefreshController: context.read<DataRefreshController>(),
          ),
        ),
        ChangeNotifierProvider<SupabaseAuthController>(
          create: (context) => SupabaseAuthController(
            SupabaseBootstrap.clientOrNull,
            context.read<SqliteSyncStateRepository>(),
            authCallbackUrl: SupabaseRuntimeConfig.authCallbackUrl,
            initialSnapshotQueue: context.read<SyncInitialSnapshotQueue>(),
          )..load(),
        ),
        Provider<GoalRepository>(
          create: (context) => SqliteGoalRepository(
            context.read<AppDatabase>(),
            changeRecorder: context.read<SyncChangeRecorder>(),
          ),
        ),
        Provider<TaskRepository>(
          create: (context) => SqliteTaskRepository(
            context.read<AppDatabase>(),
            changeRecorder: context.read<SyncChangeRecorder>(),
          ),
        ),
        Provider<DocumentRepository>(
          create: (context) => SqliteDocumentRepository(
            context.read<AppDatabase>(),
            changeRecorder: context.read<SyncChangeRecorder>(),
          ),
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
          create: (context) => SqliteReminderRepository(
            context.read<AppDatabase>(),
            changeRecorder: context.read<SyncChangeRecorder>(),
          ),
        ),
        Provider<ReminderInbox>(
          create: (context) => ReminderInbox(
            reminderRepository: context.read<ReminderRepository>(),
            taskRepository: context.read<TaskRepository>(),
            notificationService: context.read<NotificationService>(),
            remindersPaused: (now) {
              if (!Platform.isWindows) {
                return false;
              }

              return context
                  .read<SettingsController>()
                  .settings
                  .windowsRemindersPaused(now);
            },
          ),
        ),
        Provider<TaskReminderService>(
          create: (context) =>
              TaskReminderService(context.read<ReminderRepository>()),
        ),
        Provider<CompactReminderService>(
          create: (context) => CompactReminderService(
            taskRepository: context.read<TaskRepository>(),
            reminderRepository: context.read<ReminderRepository>(),
          ),
        ),
        ChangeNotifierProxyProvider<SettingsController,
            DesktopWindowController>(
          create: (_) => DesktopWindowController()..initialize(),
          update: (_, settingsController, controller) {
            final desktopWindowController =
                controller ?? (DesktopWindowController()..initialize());
            desktopWindowController.updateSettings(
              settingsController.settings,
              saveCompactPosition:
                  settingsController.updateWindowsCompactPosition,
              pauseReminders: settingsController.pauseWindowsRemindersFor,
              resumeReminders: settingsController.resumeWindowsReminders,
            );
            return desktopWindowController;
          },
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
