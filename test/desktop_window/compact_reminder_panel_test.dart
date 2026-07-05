import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/data_refresh_controller.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/desktop_window/application/compact_reminder_service.dart';
import 'package:evoly/features/desktop_window/presentation/compact_reminder_panel.dart';
import 'package:evoly/features/reminders/application/task_reminder_service.dart';
import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

void main() {
  testWidgets('renders folded and expanded compact reminder states',
      (tester) async {
    tester.view.physicalSize = const Size(360, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final semantics = tester.ensureSemantics();
    try {
      final now = DateTime.now();
      final tasks = [
        _task(
          'task-1',
          '这是一个很长很长的高优先级任务标题，用来确认迷你面板不会因为文字直接溢出',
          Priority.high,
          now.add(const Duration(hours: 1)),
        ),
        _task(
          'task-2',
          '第二项高优先级任务',
          Priority.high,
          now.add(const Duration(hours: 2)),
        ),
      ];
      final reminders = [
        _reminder('reminder-1', 'task-1', now.add(const Duration(minutes: 30))),
      ];

      await tester.pumpWidget(
        _compactPanelHarness(
          tasks: tasks,
          reminders: reminders,
          expanded: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('提醒面板'), findsOneWidget);
      expect(find.text('下一个提醒'), findsOneWidget);
      expect(find.text('待提醒'), findsOneWidget);
      expect(find.text('未完成'), findsOneWidget);
      expect(find.text('已到时'), findsOneWidget);
      expect(find.text('高优先级'), findsNothing);
      expect(find.bySemanticsLabel('展开'), findsOneWidget);
      expect(find.bySemanticsLabel('刷新'), findsNothing);
      expect(tester.takeException(), isNull);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('提醒面板')));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('刷新'), findsOneWidget);

      await tester.pumpWidget(
        _compactPanelHarness(
          tasks: tasks,
          reminders: reminders,
          expanded: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('高优先级'), findsOneWidget);
      expect(find.text('第二项高优先级任务'), findsOneWidget);
      expect(find.bySemanticsLabel('打开完整模式'), findsOneWidget);
      expect(find.bySemanticsLabel('完成'), findsNothing);

      await mouse.moveTo(tester.getCenter(find.text('第二项高优先级任务')));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('完成'), findsOneWidget);
      expect(find.bySemanticsLabel('延后到明天'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('shows saved position feedback after dragging', (tester) async {
    tester.view.physicalSize = const Size(360, 184);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var dragStarted = 0;
    var dragEnded = 0;

    await tester.pumpWidget(
      _compactPanelHarness(
        tasks: const [],
        reminders: const [],
        expanded: false,
        onStartDrag: () => dragStarted += 1,
        onEndDrag: () => dragEnded += 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('提醒面板'), const Offset(24, 0));
    await tester.pumpAndSettle();

    expect(dragStarted, 1);
    expect(dragEnded, 1);
    expect(find.text('位置已保存'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text('位置已保存'), findsNothing);
  });

  testWidgets('removes outer border and fades chrome after hover exits',
      (tester) async {
    tester.view.physicalSize = const Size(360, 184);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _compactPanelHarness(
        tasks: const [],
        reminders: const [],
        expanded: false,
      ),
    );
    await tester.pumpAndSettle();

    var decoration = _compactPanelDecoration(tester);
    expect(decoration.border, isNull);
    expect(decoration.boxShadow, isNull);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(180, 92));
    await tester.pump();

    decoration = _compactPanelDecoration(tester);
    expect(decoration.border, isNull);
    expect(decoration.boxShadow, isNotNull);

    await mouse.moveTo(const Offset(420, 240));
    await tester.pump(const Duration(milliseconds: 500));

    decoration = _compactPanelDecoration(tester);
    expect(decoration.boxShadow, isNotNull);

    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pumpAndSettle();

    decoration = _compactPanelDecoration(tester);
    expect(decoration.border, isNull);
    expect(decoration.boxShadow, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapses from expanded state without bottom overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final tasks = [
      _task(
        'task-1',
        '很长的高优先级任务标题，用来覆盖收起动画时的布局边界',
        Priority.high,
        now.add(const Duration(hours: 1)),
      ),
      _task(
        'task-2',
        '第二个高优先级任务',
        Priority.high,
        now.add(const Duration(hours: 2)),
      ),
      _task(
        'task-3',
        '第三个高优先级任务',
        Priority.high,
        now.add(const Duration(hours: 3)),
      ),
    ];
    final reminders = [
      _reminder('reminder-1', 'task-1', now.add(const Duration(minutes: 30))),
    ];

    await tester.pumpWidget(
      _compactPanelHarness(
        tasks: tasks,
        reminders: reminders,
        expanded: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(360, 184);
    await tester.pumpWidget(
      _compactPanelHarness(
        tasks: tasks,
        reminders: reminders,
        expanded: false,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

BoxDecoration _compactPanelDecoration(WidgetTester tester) {
  for (final container
      in tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer))) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration && decoration.gradient != null) {
      return decoration;
    }
  }

  fail('Compact panel decoration not found.');
}

Widget _compactPanelHarness({
  required List<TaskItem> tasks,
  required List<Reminder> reminders,
  required bool expanded,
  VoidCallback? onStartDrag,
  VoidCallback? onEndDrag,
}) {
  final taskRepository = _FakeTaskRepository(tasks);
  final reminderRepository = _FakeReminderRepository(reminders);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DataRefreshController>(
        create: (_) => DataRefreshController(),
      ),
      Provider<TaskRepository>.value(value: taskRepository),
      Provider<ReminderRepository>.value(value: reminderRepository),
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
    ],
    child: MaterialApp(
      home: SizedBox(
        width: 360,
        height: expanded ? 360 : 184,
        child: CompactReminderPanel(
          expanded: expanded,
          onToggleExpanded: () {},
          onOpenFullMode: (_) {},
          onHideWindow: () {},
          onStartDrag: onStartDrag ?? () {},
          onEndDrag: onEndDrag ?? () {},
        ),
      ),
    ),
  );
}

TaskItem _task(
  String id,
  String title,
  Priority priority,
  DateTime dueDateTime,
) {
  final now = DateTime.now();
  return TaskItem(
    id: id,
    goalId: 'goal-1',
    title: title,
    priority: priority,
    status: TaskStatus.pending,
    estimatedMinutes: 30,
    dueDateTime: dueDateTime,
    createdAt: now,
    updatedAt: now,
  );
}

Reminder _reminder(String id, String taskId, DateTime remindAt) {
  final now = DateTime.now();
  return Reminder(
    id: id,
    targetType: ReminderTargetType.task,
    targetId: taskId,
    remindAt: remindAt,
    repeatRule: RepeatRule.none,
    enabled: true,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeTaskRepository implements TaskRepository {
  const _FakeTaskRepository(this.tasks);

  final List<TaskItem> tasks;

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
  Future<void> save(TaskItem task) async {}
}

class _FakeReminderRepository implements ReminderRepository {
  const _FakeReminderRepository(this.reminders);

  final List<Reminder> reminders;

  @override
  Future<void> disable(String id) async {}

  @override
  Future<void> disableForTask(String taskId) async {}

  @override
  Future<Reminder?> findByTaskId(String taskId) async {
    return reminders
        .where((reminder) => reminder.targetId == taskId)
        .firstOrNull;
  }

  @override
  Future<List<Reminder>> findDue(DateTime now) async => const [];

  @override
  Future<List<Reminder>> findEnabled() async => reminders;

  @override
  Future<List<Reminder>> findUpcoming(DateTime from, DateTime to) async {
    return reminders;
  }

  @override
  Future<void> markFired(String id, DateTime firedAt) async {}

  @override
  Future<void> save(Reminder reminder) async {}
}
