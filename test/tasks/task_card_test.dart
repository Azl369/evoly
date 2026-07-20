import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evoly/app/theme.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';
import 'package:evoly/features/tasks/presentation/widgets/task_card.dart';

void main() {
  testWidgets('shows project context label when provided', (tester) async {
    await _pumpTaskCard(
      tester,
      TaskCard(
        task: _task(),
        contextLabel: '项目：V0.4 项目',
      ),
    );

    expect(find.text('项目：V0.4 项目'), findsOneWidget);
    expect(find.byIcon(Icons.workspaces_outline), findsOneWidget);
    expect(find.text('30 分钟'), findsNothing);
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
  });

  testWidgets('does not show project context label when omitted',
      (tester) async {
    await _pumpTaskCard(
      tester,
      TaskCard(task: _task()),
    );

    expect(find.textContaining('项目：'), findsNothing);
    expect(find.byIcon(Icons.workspaces_outline), findsNothing);
  });

  testWidgets('shows delayed status when pending task is past due',
      (tester) async {
    await _pumpTaskCard(
      tester,
      TaskCard(
        task: _task(
          dueDateTime: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ),
    );

    expect(find.text('已延期'), findsOneWidget);
    expect(find.text('待完成'), findsNothing);
  });

  testWidgets('constrains long context label on narrow task cards',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpTaskCard(
      tester,
      SizedBox(
        width: 340,
        child: TaskCard(
          task: _task(),
          contextLabel: '项目：客户问题 AXI QSPI 访问异常和兼容性验证',
          trailing: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.drag_indicator_rounded),
              Icon(Icons.more_vert_rounded),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.workspaces_outline), findsOneWidget);
  });

  testWidgets('hover keeps task card size stable', (tester) async {
    await _pumpTaskCard(
      tester,
      TaskCard(
        task: _task(),
        contextLabel: '项目：V0.4 项目',
        trailing: const Icon(Icons.more_vert_rounded),
      ),
    );

    final card = find.byType(TaskCard);
    final before = tester.getSize(card);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(card));
    await tester.pumpAndSettle();
    final after = tester.getSize(card);

    expect(after, before);
    await gesture.removePointer();
  });

  testWidgets('formats due time for today, tomorrow, future, and overdue',
      (tester) async {
    final now = DateTime.now();
    final todayDue = DateTime(now.year, now.month, now.day, 23, 59);
    final tomorrowDue = DateTime(
      now.year,
      now.month,
      now.day,
      10,
    ).add(const Duration(days: 1));
    final futureDue = DateTime(
      now.year,
      now.month,
      now.day,
      10,
    ).add(const Duration(days: 4));
    final overdue = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
    ).subtract(const Duration(days: 1));

    await _pumpTaskCard(
      tester,
      Column(
        children: [
          TaskCard(task: _task(id: 'today', dueDateTime: todayDue)),
          TaskCard(task: _task(id: 'tomorrow', dueDateTime: tomorrowDue)),
          TaskCard(task: _task(id: 'future', dueDateTime: futureDue)),
          TaskCard(task: _task(id: 'overdue', dueDateTime: overdue)),
        ],
      ),
    );

    expect(find.text('截止 今天 23:59'), findsOneWidget);
    expect(find.text('截止 明天 10:00'), findsOneWidget);
    expect(
      find.text('截止 ${futureDue.month}月${futureDue.day}日 10:00'),
      findsOneWidget,
    );
    expect(find.text('已延期 昨天 23:59'), findsOneWidget);
  });

  testWidgets('shows weekly repeat metadata', (tester) async {
    await _pumpTaskCard(
      tester,
      TaskCard(
        task: _task().copyWith(
          repeatRule: TaskRepeatRule.weekly,
          repeatSeriesId: 'series-1',
        ),
      ),
    );

    expect(find.text('每周'), findsOneWidget);
    expect(find.byIcon(Icons.event_repeat_rounded), findsOneWidget);
  });
}

Future<void> _pumpTaskCard(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

TaskItem _task({String id = 'task-1', DateTime? dueDateTime}) {
  final now = DateTime(2026, 1, 1, 9);
  return TaskItem(
    id: id,
    goalId: 'goal-1',
    title: '整理发布清单',
    priority: Priority.medium,
    status: TaskStatus.pending,
    estimatedMinutes: 30,
    dueDateTime: dueDateTime,
    createdAt: now,
    updatedAt: now,
  );
}
