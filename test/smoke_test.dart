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
import 'package:evoly/features/goals/data/goal_repository.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/features/goals/presentation/goal_detail_page.dart';
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

    expect(find.text('计划'), findsWidgets);
    expect(find.text('计划概览'), findsOneWidget);
    expect(find.text('待推进'), findsWidgets);
    expect(find.text('Evoly Coach 今日建议'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pump();

    expect(find.text('计划任务'), findsOneWidget);
    expect(find.text('今日到期'), findsOneWidget);
    expect(find.text('项目：V0.4 项目'), findsWidgets);
  });

  testWidgets('shows fallback project label when project mapping is missing',
      (tester) async {
    final now = DateTime.now();
    final task = TaskItem(
      id: 'task-missing-project',
      goalId: 'missing-goal',
      title: '归属暂未同步的任务',
      priority: Priority.medium,
      status: TaskStatus.pending,
      estimatedMinutes: 20,
      dueDateTime: DateTime(now.year, now.month, now.day, 18),
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: _providersFor(
          taskRepository: _FakeTaskRepository([task]),
          coachContext: const CoachTodayContext(
            todayTasks: [],
            delayedGoalStats: [],
          ),
          goalRepository: _FakeGoalRepository(goals: []),
        ),
        child: const MaterialApp(home: TodayPage()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pump();

    expect(find.text('归属暂未同步的任务'), findsWidgets);
    expect(find.text('项目：未同步'), findsWidgets);
  });

  testWidgets('quick project creation saves only a project and opens detail',
      (tester) async {
    final taskRepository = _FakeTaskRepository(const []);
    final goalRepository = _FakeGoalRepository(goals: []);
    String? openedProjectId;

    await tester.pumpWidget(
      MultiProvider(
        providers: _providersFor(
          taskRepository: taskRepository,
          coachContext: const CoachTodayContext(
            todayTasks: [],
            delayedGoalStats: [],
          ),
          goalRepository: goalRepository,
        ),
        child: MaterialApp(
          home: const TodayPage(),
          onGenerateRoute: (settings) {
            openedProjectId = settings.arguments as String?;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('项目详情占位')),
              settings: settings,
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byTooltip('新建项目'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '快速创建的项目');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(goalRepository.goals, hasLength(1));
    expect(goalRepository.goals.single.title, '快速创建的项目');
    expect(goalRepository.goals.single.type, GoalType.longTerm);
    expect(goalRepository.goals.single.priority, Priority.medium);
    expect(goalRepository.goals.single.status, GoalStatus.inProgress);
    expect(goalRepository.goals.single.dueDate, isNull);
    expect(taskRepository.savedTasks, isEmpty);
    expect(openedProjectId, goalRepository.goals.single.id);
    expect(find.text('项目详情占位'), findsOneWidget);
  });

  testWidgets('moving task to another project removes it from goal detail',
      (tester) async {
    final now = DateTime.now();
    final task = TaskItem(
      id: 'task-move-project',
      goalId: 'goal-1',
      title: '需要移走的子任务',
      priority: Priority.medium,
      status: TaskStatus.pending,
      estimatedMinutes: 25,
      createdAt: now,
      updatedAt: now,
    );
    final taskRepository = _FakeTaskRepository([task]);
    final goalRepository = _FakeGoalRepository(
      goals: [
        Goal(
          id: 'goal-1',
          title: '原项目',
          type: GoalType.longTerm,
          priority: Priority.medium,
          status: GoalStatus.inProgress,
          startDate: now,
          createdAt: now,
          updatedAt: now,
        ),
        Goal(
          id: 'goal-2',
          title: '新项目',
          type: GoalType.longTerm,
          priority: Priority.medium,
          status: GoalStatus.inProgress,
          startDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: _providersFor(
          taskRepository: taskRepository,
          coachContext: const CoachTodayContext(
            todayTasks: [],
            delayedGoalStats: [],
          ),
          goalRepository: goalRepository,
        ),
        child: const MaterialApp(home: GoalDetailPage(goalId: 'goal-1')),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('需要移走的子任务'), findsOneWidget);

    await tester.tap(find.text('需要移走的子任务'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('原项目'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新项目').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(taskRepository.tasks.single.goalId, 'goal-2');
    expect(find.text('需要移走的子任务'), findsNothing);
    expect(find.text('已移动到「新项目」'), findsOneWidget);
  });

  testWidgets('shows long-running pending tasks in plan', (tester) async {
    final now = DateTime.now();
    final todayTask = TaskItem(
      id: 'task-today',
      goalId: 'goal-1',
      title: '今天要交付的任务',
      priority: Priority.high,
      status: TaskStatus.pending,
      estimatedMinutes: 25,
      dueDateTime: DateTime(now.year, now.month, now.day, 18),
      createdAt: now,
      updatedAt: now,
    );
    final longRunningTask = TaskItem(
      id: 'task-long-running',
      goalId: 'goal-1',
      title: '长期推进的无截止任务',
      priority: Priority.medium,
      status: TaskStatus.pending,
      estimatedMinutes: 45,
      createdAt: now.subtract(const Duration(minutes: 2)),
      updatedAt: now,
    );
    final completedLongRunningTask = TaskItem(
      id: 'task-completed-long-running',
      goalId: 'goal-1',
      title: '已经完成的无截止任务',
      priority: Priority.high,
      status: TaskStatus.completed,
      estimatedMinutes: 15,
      completedAt: now,
      createdAt: now.subtract(const Duration(minutes: 3)),
      updatedAt: now,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: _providersFor(
          taskRepository: _FakeTaskRepository([
            todayTask,
            longRunningTask,
            completedLongRunningTask,
          ]),
          coachContext: CoachTodayContext(
            todayTasks: [
              CoachTaskContext(
                id: todayTask.id,
                goalId: todayTask.goalId,
                title: todayTask.title,
                priority: todayTask.priority,
                status: todayTask.status,
                estimatedMinutes: todayTask.estimatedMinutes,
                dueDateTime: todayTask.dueDateTime,
                goalTitle: 'V0.4',
              ),
            ],
            delayedGoalStats: const [],
          ),
        ),
        child: const MaterialApp(home: TodayPage()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('计划'), findsWidgets);
    expect(find.text('1 今日到期'), findsOneWidget);
    expect(find.text('1 待安排'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pump();

    expect(find.text('今日到期'), findsOneWidget);
    expect(find.text('高优先级'), findsWidgets);
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pump();
    expect(find.text('待安排'), findsOneWidget);
    expect(find.text('今天要交付的任务'), findsWidgets);
    expect(find.text('长期推进的无截止任务'), findsOneWidget);
    expect(find.text('今天已完成'), findsOneWidget);
    expect(find.text('已经完成的无截止任务'), findsOneWidget);
  });

  testWidgets('groups due tasks by priority in plan', (tester) async {
    final now = DateTime.now();
    final tasks = [
      _planTask(
        id: 'high',
        title: '高优先级今日到期',
        priority: Priority.high,
        now: now,
        dueDateTime: DateTime(now.year, now.month, now.day, 10),
      ),
      _planTask(
        id: 'medium',
        title: '中优先级今日到期',
        priority: Priority.medium,
        now: now,
        dueDateTime: DateTime(now.year, now.month, now.day, 12),
      ),
      _planTask(
        id: 'low',
        title: '低优先级今日到期',
        priority: Priority.low,
        now: now,
        dueDateTime: DateTime(now.year, now.month, now.day, 14),
      ),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: _providersFor(
          taskRepository: _FakeTaskRepository(tasks),
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
                goalTitle: 'V0.4',
              );
            }).toList(),
            delayedGoalStats: const [],
          ),
        ),
        child: const MaterialApp(home: TodayPage()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pump();

    expect(find.text('今日到期'), findsOneWidget);
    expect(find.text('高优先级'), findsWidgets);
    expect(find.text('中优先级'), findsWidgets);
    expect(find.text('低优先级'), findsWidgets);
    expect(find.text('高优先级今日到期'), findsWidgets);
    expect(find.text('中优先级今日到期'), findsWidgets);
    expect(find.text('低优先级今日到期'), findsWidgets);
  });

  testWidgets('shows reorder handles within the same priority in plan',
      (tester) async {
    final now = DateTime.now();
    final tasks = [
      _planTask(
        id: 'first',
        title: '第一项高优先级',
        priority: Priority.high,
        sortOrder: 1000,
        now: now,
        dueDateTime: DateTime(now.year, now.month, now.day, 10),
      ),
      _planTask(
        id: 'second',
        title: '第二项高优先级',
        priority: Priority.high,
        sortOrder: 2000,
        now: now,
        dueDateTime: DateTime(now.year, now.month, now.day, 12),
      ),
    ];
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
                goalTitle: 'V0.4',
              );
            }).toList(),
            delayedGoalStats: const [],
          ),
        ),
        child: const MaterialApp(home: TodayPage()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pump();

    expect(find.byIcon(Icons.drag_indicator_rounded), findsNWidgets(2));
    expect(taskRepository.lastReorderedTaskIds, isEmpty);
  });

  testWidgets('supports consecutive upward reorders within a priority group',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final tasks = [
      _planTask(
        id: 'first',
        title: '第一项高优先级',
        priority: Priority.high,
        sortOrder: 1000,
        now: now,
        dueDateTime: DateTime(now.year, now.month, now.day, 10),
      ),
      _planTask(
        id: 'second',
        title: '第二项高优先级',
        priority: Priority.high,
        sortOrder: 2000,
        now: now,
        dueDateTime: DateTime(now.year, now.month, now.day, 12),
      ),
      _planTask(
        id: 'third',
        title: '第三项高优先级',
        priority: Priority.high,
        sortOrder: 3000,
        now: now,
        dueDateTime: DateTime(now.year, now.month, now.day, 14),
      ),
    ];
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
                goalTitle: 'V0.4',
              );
            }).toList(),
            delayedGoalStats: const [],
          ),
        ),
        child: const MaterialApp(home: TodayPage()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    final handles = find.byIcon(Icons.drag_indicator_rounded);
    expect(handles, findsNWidgets(3));

    await tester.drag(handles.at(1), const Offset(0, -72));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(taskRepository.lastReorderedTaskIds, ['second', 'first', 'third']);

    await tester.drag(handles.at(2), const Offset(0, -72));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(taskRepository.lastReorderedTaskIds, ['second', 'third', 'first']);
  });

  testWidgets('starts reorder movement during the first drag gesture',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final tasks = [
      _planTask(
        id: 'first',
        title: 'First high priority task',
        priority: Priority.high,
        sortOrder: 1000,
        now: now,
        dueDateTime: DateTime(now.year, now.month, now.day, 10),
      ),
      _planTask(
        id: 'second',
        title: 'Second high priority task',
        priority: Priority.high,
        sortOrder: 2000,
        now: now,
        dueDateTime: DateTime(now.year, now.month, now.day, 12),
      ),
      _planTask(
        id: 'third',
        title: 'Third high priority task',
        priority: Priority.high,
        sortOrder: 3000,
        now: now,
        dueDateTime: DateTime(now.year, now.month, now.day, 14),
      ),
    ];
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
                goalTitle: 'V0.4',
              );
            }).toList(),
            delayedGoalStats: const [],
          ),
        ),
        child: const MaterialApp(home: TodayPage()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    final handles = find.byIcon(Icons.drag_indicator_rounded);
    expect(handles, findsNWidgets(3));

    final gesture = await tester.startGesture(tester.getCenter(handles.at(1)));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -84));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(taskRepository.lastReorderedTaskIds, ['second', 'first', 'third']);
  });

  testWidgets('reorders variable height task cards without layout exceptions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final tasks = [
      _planTask(
        id: 'compact',
        title: 'Compact high priority task',
        priority: Priority.high,
        sortOrder: 1000,
        now: now,
        dueDateTime: DateTime(now.year, now.month, now.day, 10),
      ),
      _planTask(
        id: 'expanded',
        title:
            'Expanded high priority task with a title that wraps on narrow screens',
        description:
            'This task intentionally uses longer detail text so the reorder lane measures the rendered card height instead of assuming a fixed row.',
        priority: Priority.high,
        sortOrder: 2000,
        now: now,
        dueDateTime: DateTime(now.year, now.month, now.day, 12),
      ),
      _planTask(
        id: 'stable',
        title: 'Stable high priority task',
        priority: Priority.high,
        sortOrder: 3000,
        now: now,
        dueDateTime: DateTime(now.year, now.month, now.day, 14),
      ),
    ];
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
                goalTitle: 'V0.4',
              );
            }).toList(),
            delayedGoalStats: const [],
          ),
        ),
        child: const MaterialApp(home: TodayPage()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(
      find
          .text(
            'Expanded high priority task with a title that wraps on narrow screens',
          )
          .first,
      96,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final handles = find.byIcon(Icons.drag_indicator_rounded);
    expect(handles, findsNWidgets(3));

    await tester.drag(handles.at(1), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(taskRepository.lastReorderedTaskIds, [
      'expanded',
      'compact',
      'stable',
    ]);
  });

  testWidgets('keeps reorder groups stable when priority repeats by section',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final tasks = [
      _planTask(
        id: 'due-first',
        title: '今日高优先级第一项',
        priority: Priority.high,
        sortOrder: 1000,
        now: now,
        dueDateTime: DateTime(now.year, now.month, now.day, 10),
      ),
      _planTask(
        id: 'due-second',
        title: '今日高优先级第二项',
        priority: Priority.high,
        sortOrder: 2000,
        now: now,
        dueDateTime: DateTime(now.year, now.month, now.day, 12),
      ),
      _planTask(
        id: 'unscheduled-first',
        title: '待安排高优先级第一项',
        priority: Priority.high,
        sortOrder: 3000,
        now: now,
      ),
      _planTask(
        id: 'unscheduled-second',
        title: '待安排高优先级第二项',
        priority: Priority.high,
        sortOrder: 4000,
        now: now,
      ),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: _providersFor(
          taskRepository: _FakeTaskRepository(tasks),
          coachContext: CoachTodayContext(
            todayTasks: tasks.take(2).map((task) {
              return CoachTaskContext(
                id: task.id,
                goalId: task.goalId,
                title: task.title,
                priority: task.priority,
                status: task.status,
                estimatedMinutes: task.estimatedMinutes,
                dueDateTime: task.dueDateTime,
                goalTitle: 'V0.4',
              );
            }).toList(),
            delayedGoalStats: const [],
          ),
        ),
        child: const MaterialApp(home: TodayPage()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('今日到期'), findsOneWidget);
    expect(find.text('待安排'), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNWidgets(4));
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
  _FakeGoalRepository? goalRepository,
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
    Provider<GoalRepository>.value(
        value: goalRepository ?? _FakeGoalRepository()),
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

TaskItem _planTask({
  required String id,
  required String title,
  required Priority priority,
  required DateTime now,
  String description = '',
  DateTime? dueDateTime,
  int sortOrder = 0,
}) {
  return TaskItem(
    id: id,
    goalId: 'goal-1',
    title: title,
    description: description,
    priority: priority,
    status: TaskStatus.pending,
    estimatedMinutes: 20,
    dueDateTime: dueDateTime,
    createdAt: now,
    updatedAt: now,
    sortOrder: sortOrder,
  );
}

class _FakeGoalRepository implements GoalRepository {
  _FakeGoalRepository({List<Goal>? goals})
      : goals = goals ??
            [
              Goal(
                id: 'goal-1',
                title: 'V0.4 项目',
                type: GoalType.longTerm,
                priority: Priority.medium,
                status: GoalStatus.inProgress,
                startDate: DateTime(2026),
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ];

  final List<Goal> goals;

  @override
  Future<void> delete(String id) async {
    goals.removeWhere((goal) => goal.id == id);
  }

  @override
  Future<List<Goal>> findAll() async => goals;

  @override
  Future<Goal?> findById(String id) async {
    return goals.where((goal) => goal.id == id).firstOrNull;
  }

  @override
  Future<void> save(Goal goal) async {
    final index = goals.indexWhere((item) => item.id == goal.id);
    if (index == -1) {
      goals.add(goal);
    } else {
      goals[index] = goal;
    }
  }
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
  List<String> lastReorderedTaskIds = const [];

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
  Future<List<TaskItem>> findPlanningCandidates(DateTime today) async {
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    return tasks.where((task) {
      if (task.status == TaskStatus.completed ||
          task.status == TaskStatus.cancelled) {
        return false;
      }

      final dueDateTime = task.dueDateTime;
      return dueDateTime == null || dueDateTime.isBefore(end);
    }).toList();
  }

  @override
  Future<List<TaskItem>> findCompletedToday(DateTime today) async {
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    return tasks.where((task) {
      final completedAt = task.completedAt;
      return task.status == TaskStatus.completed &&
          completedAt != null &&
          !completedAt.isBefore(start) &&
          completedAt.isBefore(end);
    }).toList();
  }

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

  @override
  Future<void> reorderWithinPriority({
    required Priority priority,
    required List<String> orderedTaskIds,
  }) async {
    lastReorderedTaskIds = [...orderedTaskIds];
    for (var index = 0; index < orderedTaskIds.length; index += 1) {
      final taskIndex =
          tasks.indexWhere((task) => task.id == orderedTaskIds[index]);
      if (taskIndex != -1 && tasks[taskIndex].priority == priority) {
        tasks[taskIndex] = tasks[taskIndex].copyWith(
          sortOrder: (index + 1) * 1000,
        );
      }
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
    NotificationRepeat repeat = NotificationRepeat.none,
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
  Future<void> setHasShadow(bool value) async {}

  @override
  Future<void> setOpacity(double opacity) async {}

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
