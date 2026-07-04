import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';
import 'package:evoly/features/tasks/presentation/widgets/task_edit_sheet.dart';

void main() {
  testWidgets('updates priority and status from direct option chips',
      (tester) async {
    final now = DateTime(2026, 1, 1, 9);
    final task = TaskItem(
      id: 'task-1',
      goalId: 'goal-1',
      title: '桌面编辑任务',
      priority: Priority.low,
      status: TaskStatus.pending,
      estimatedMinutes: 30,
      createdAt: now,
      updatedAt: now,
    );
    TaskItem? savedTask;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskEditSheet(
            title: '编辑任务',
            task: task,
            reminder: null,
            onSave: (updatedTask, _) async {
              savedTask = updatedTask;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(_chipWithText('高'));
    await tester.tap(_chipWithText('已完成'));

    final doneButton = find.ancestor(
      of: find.text('完成'),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(doneButton);
    await tester.tap(doneButton);
    await tester.pumpAndSettle();

    expect(savedTask?.priority, Priority.high);
    expect(savedTask?.status, TaskStatus.completed);
    expect(savedTask?.completedAt, isNotNull);
  });
}

Finder _chipWithText(String text) {
  return find.ancestor(
    of: find.text(text),
    matching: find.byType(ChoiceChip),
  );
}
