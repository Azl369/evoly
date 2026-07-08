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
}

Future<void> _pumpTaskCard(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

TaskItem _task() {
  final now = DateTime(2026, 1, 1, 9);
  return TaskItem(
    id: 'task-1',
    goalId: 'goal-1',
    title: '整理发布清单',
    priority: Priority.medium,
    status: TaskStatus.pending,
    estimatedMinutes: 30,
    createdAt: now,
    updatedAt: now,
  );
}
