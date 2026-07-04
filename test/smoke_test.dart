import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:evoly/app/data_refresh_controller.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/coach/application/rule_based_coach_service.dart';
import 'package:evoly/features/coach/data/coach_repository.dart';
import 'package:evoly/features/desktop_window/application/desktop_window_controller.dart';
import 'package:evoly/features/desktop_window/application/desktop_window_host.dart';
import 'package:evoly/features/documents/data/document_repository.dart';
import 'package:evoly/features/documents/domain/document_folder_summary.dart';
import 'package:evoly/features/documents/domain/evoly_document.dart';
import 'package:evoly/features/reminders/application/reminder_inbox.dart';
import 'package:evoly/features/reminders/application/task_reminder_service.dart';
import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';
import 'package:evoly/features/today/presentation/today_page.dart';
import 'package:evoly/services/notification_service.dart';

void main() {
  testWidgets('renders today page', (tester) async {
    final now = DateTime.now();
    final task = TaskItem(
      id: 'task-1',
      goalId: 'goal-1',
      title: '写一页 V0.2 计划',
      priority: Priority.high,
      status: TaskStatus.pending,
      estimatedMinutes: 30,
      dueDateTime: DateTime(now.year, now.month, now.day, 18),
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: _providersFor(
          taskRepository: _FakeTaskRepository([task]),
          coachContext: CoachTodayContext(
            todayTasks: [
              CoachTaskContext(
                id: task.id,
                goalId: task.goalId,
                title: task.title,
                priority: task.priority,
                status: task.status,
                estimatedMinutes: task.estimatedMinutes,
                dueDateTime: task.dueDateTime,
                goalTitle: 'V0.2',
              ),
            ],
            delayedGoalStats: const [],
          ),
        ),
        child: const MaterialApp(home: TodayPage()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('今日计划'), findsOneWidget);
    expect(find.text('Evoly Coach 今日建议'), findsOneWidget);
  });

  testWidgets('keeps only coach top 3 after confirmation', (tester) async {
    final now = DateTime.now();
    final tasks = List.generate(4, (index) {
      return TaskItem(
        id: 'task-$index',
        goalId: 'goal-1',
        title: '任务 $index',
        priority: index == 3 ? Priority.low : Priority.high,
        status: TaskStatus.pending,
        estimatedMinutes: 80,
        dueDateTime: DateTime(now.year, now.month, now.day, 18 + index),
        createdAt: now,
        updatedAt: now,
      );
    });
    final taskRepository = _FakeTaskRepository(tasks);

    await tester.pumpWidget(
      MultiProvider(
        providers: _providersFor(
          taskRepository: taskRepository,
          coachContext: CoachTodayContext(
            todayTasks: tasks.map((task) {
              return CoachTaskContext(
                id: task.id,
                goalId: task.goalId,
                title: task.title,
                priority: task.priority,
                status: task.status,
                estimatedMinutes: task.estimatedMinutes,
                dueDateTime: task.dueDateTime,
                goalTitle: 'V0.2',
              );
            }).toList(),
            delayedGoalStats: const [],
          ),
        ),
        child: const MaterialApp(home: TodayPage()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.drag(
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pump();
    await tester.tap(find.text('只保留 Top 3'));
    await tester.pumpAndSettle();

    expect(find.text('Coach 调整草案'), findsOneWidget);
    expect(find.text('保留今天推进（3）'), findsOneWidget);
    expect(find.text('延期到明天（1）'), findsOneWidget);

    await tester.tap(find.text('确认执行'));
    await tester.pump(const Duration(seconds: 1));

    final postponedTask = taskRepository.savedTasks.lastWhere(
      (task) => task.id == 'task-3',
    );
    expect(postponedTask.status, TaskStatus.postponed);
    expect(find.textContaining('已延期'), findsWidgets);
  });

  testWidgets('opens pending desktop task once', (tester) async {
    final now = DateTime.now();
    final task = TaskItem(
      id: 'task-open-from-compact',
      goalId: 'goal-1',
      title: '从迷你面板打开的任务',
      priority: Priority.high,
      status: TaskStatus.pending,
      estimatedMinutes: 30,
      dueDateTime: DateTime(now.year, now.month, now.day, 18),
      createdAt: now,
      updatedAt: now,
    );
    final desktopWindowController = DesktopWindowController(
      host: _FakeDesktopWindowHost(),
    );
    await desktopWindowController.initialize();

    await tester.pumpWidget(
      MultiProvider(
        providers: _providersFor(
          taskRepository: _FakeTaskRepository([task]),
          coachContext: CoachTodayContext(
            todayTasks: [
              CoachTaskContext(
                id: task.id,
                goalId: task.goalId,
                title: task.title,
                priority: task.priority,
                status: task.status,
                estimatedMinutes: task.estimatedMinutes,
                dueDateTime: task.dueDateTime,
                goalTitle: 'V0.2',
              ),
            ],
            delayedGoalStats: const [],
          ),
          desktopWindowController: desktopWindowController,
        ),
        child: const MaterialApp(home: TodayPage()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await desktopWindowController.enterFullMode(taskId: task.id);
    await tester.pumpAndSettle();

    expect(find.text('编辑任务'), findsOneWidget);
    expect(desktopWindowController.pendingTaskId, isNull);

    await tester.pumpAndSettle();
    expect(find.text('编辑任务'), findsOneWidget);
  });
}

List<SingleChildWidget> _providersFor({
  required _FakeTaskRepository taskRepository,
  required CoachTodayContext coachContext,
  DesktopWindowController? desktopWindowController,
}) {
  return [
    ChangeNotifierProvider<DataRefreshController>(
      create: (_) => DataRefreshController(),
    ),
    if (desktopWindowController != null)
      ChangeNotifierProvider<DesktopWindowController>.value(
        value: desktopWindowController,
      ),
    Provider<TaskRepository>.value(value: taskRepository),
    Provider<DocumentRepository>.value(value: _FakeDocumentRepository()),
    Provider<ReminderRepository>.value(value: _FakeReminderRepository()),
    Provider<NotificationService>.value(
      value: const _FakeNotificationService(),
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
    Provider<CoachRepository>.value(
      value: _FakeCoachRepository(coachContext),
    ),
    Provider<RuleBasedCoachService>(
      create: (context) =>
          RuleBasedCoachService(context.read<CoachRepository>()),
    ),
  ];
}

class _FakeDocumentRepository implements DocumentRepository {
  final List<EvolyDocument> documents = [];

  @override
  Future<void> delete(String id) async {
    documents.removeWhere((document) => document.id == id);
  }

  @override
  Future<List<EvolyDocument>> findAll({
    String? query,
    DocumentType? type,
  }) async {
    return documents;
  }

  @override
  Future<List<EvolyDocument>> findByGoalId(String goalId, {int? limit}) async {
    return limit == null ? documents : documents.take(limit).toList();
  }

  @override
  Future<EvolyDocument?> findById(String id) async {
    return documents.where((document) => document.id == id).firstOrNull;
  }

  @override
  Future<List<DocumentFolderSummary>> findGoalFolders({String? query}) async {
    return const [];
  }

  @override
  Future<List<String>> findLinkedGoalIds(String documentId) async {
    return const [];
  }

  @override
  Future<List<EvolyDocument>> findUnfiled({String? query}) async {
    return documents;
  }

  @override
  Future<void> replaceLinkedGoals(
      String documentId, List<String> goalIds) async {}

  @override
  Future<void> save(EvolyDocument document) async {
    documents.add(document);
  }
}

class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository(this.tasks);

  final List<TaskItem> tasks;
  final List<TaskItem> savedTasks = [];

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
  Future<void> save(TaskItem task) async {
    savedTasks.add(task);
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index == -1) {
      tasks.add(task);
    } else {
      tasks[index] = task;
    }
  }
}

class _FakeCoachRepository implements CoachRepository {
  const _FakeCoachRepository(this.context);

  final CoachTodayContext context;

  @override
  Future<CoachTodayContext> loadTodayContext(DateTime now) async => context;
}

class _FakeReminderRepository implements ReminderRepository {
  @override
  Future<void> disable(String id) async {}

  @override
  Future<void> disableForTask(String taskId) async {}

  @override
  Future<Reminder?> findByTaskId(String taskId) async => null;

  @override
  Future<List<Reminder>> findDue(DateTime now) async => const [];

  @override
  Future<List<Reminder>> findEnabled() async => const [];

  @override
  Future<List<Reminder>> findUpcoming(DateTime from, DateTime to) async {
    return const [];
  }

  @override
  Future<void> markFired(String id, DateTime firedAt) async {}

  @override
  Future<void> save(Reminder reminder) async {}
}

class _FakeNotificationService implements NotificationService {
  const _FakeNotificationService();

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
  }) async {}

  @override
  Future<void> showNow({
    required String id,
    required String title,
    required String body,
  }) async {}
}

class _FakeDesktopWindowHost implements DesktopWindowHost {
  @override
  bool isWindows = false;

  @override
  Future<void> initialize({
    required VoidCallback onWindowClose,
    required VoidCallback onTrayIconMouseDown,
    required VoidCallback onTrayIconRightMouseDown,
    required ValueChanged<DesktopTrayMenuAction> onTrayMenuAction,
  }) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> setPreventClose(bool value) async {}

  @override
  Future<void> setTitleBarStyle(
    DesktopWindowTitleBarStyle style, {
    required bool windowButtonVisibility,
  }) async {}

  @override
  Future<void> setAsFrameless() async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setWindowEffect(
    DesktopWindowEffect effect, {
    Color color = const Color(0x00000000),
    bool dark = false,
  }) async {}

  @override
  Future<void> setAlwaysOnTop(bool value) async {}

  @override
  Future<void> setResizable(bool value) async {}

  @override
  Future<void> setMinimizable(bool value) async {}

  @override
  Future<void> setMaximizable(bool value) async {}

  @override
  Future<void> setSkipTaskbar(bool value) async {}

  @override
  Future<void> setMinimumSize(Size size) async {}

  @override
  Future<void> setMaximumSize(Size size) async {}

  @override
  Future<void> setSize(Size size) async {}

  @override
  Future<void> setBounds(Rect? bounds, {Offset? position, Size? size}) async {}

  @override
  Future<Rect> getBounds() async => Rect.zero;

  @override
  Future<void> center() async {}

  @override
  Future<void> show({bool inactive = false}) async {}

  @override
  Future<void> hide() async {}

  @override
  Future<void> destroy() async {}

  @override
  Future<void> focus() async {}

  @override
  Future<void> unmaximize() async {}

  @override
  Future<void> startDragging() async {}

  @override
  Future<DesktopDisplayInfo> getPrimaryDisplay() async {
    return const DesktopDisplayInfo(
      visiblePosition: Offset.zero,
      visibleSize: Size(1920, 1080),
    );
  }

  @override
  Future<void> initializeTray({
    required String iconPath,
    required String tooltip,
    required bool remindersPaused,
  }) async {}

  @override
  Future<void> updateTrayMenu({required bool remindersPaused}) async {}

  @override
  Future<void> destroyTray() async {}

  @override
  Future<void> popUpTrayContextMenu() async {}
}
