import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';
import 'package:evoly/features/reminders/presentation/task_reminder_picker.dart';
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
    expect(find.text('预计耗时（分钟）'), findsNothing);
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

  testWidgets('can move task to another project without changing task details',
      (tester) async {
    final now = DateTime(2026, 1, 1, 9);
    final dueDateTime = DateTime.now().add(const Duration(days: 1));
    final task = TaskItem(
      id: 'task-1',
      goalId: 'goal-1',
      title: '修正归属的任务',
      description: '保留原始说明',
      priority: Priority.low,
      status: TaskStatus.pending,
      estimatedMinutes: 45,
      dueDateTime: dueDateTime,
      createdAt: now,
      updatedAt: now,
    );
    final reminder = Reminder(
      id: 'reminder-1',
      targetType: ReminderTargetType.task,
      targetId: task.id,
      remindAt: dueDateTime.subtract(const Duration(hours: 1)),
      repeatRule: RepeatRule.none,
      enabled: true,
      createdAt: now,
      updatedAt: now,
    );
    TaskItem? savedTask;
    TaskReminderSelection? savedReminder;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskEditSheet(
            title: '编辑任务',
            task: task,
            reminder: reminder,
            availableGoals: [
              _goal(id: 'goal-1', title: '当前项目'),
              _goal(id: 'goal-2', title: '移动项目'),
            ],
            onSave: (updatedTask, reminder) async {
              savedTask = updatedTask;
              savedReminder = reminder;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('当前项目'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移动项目').last);
    await tester.pumpAndSettle();

    final doneButton = find.ancestor(
      of: find.text('完成'),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(doneButton);
    await tester.tap(doneButton);
    await tester.pumpAndSettle();

    expect(savedTask?.goalId, 'goal-2');
    expect(savedTask?.priority, Priority.low);
    expect(savedTask?.status, TaskStatus.pending);
    expect(savedTask?.estimatedMinutes, 45);
    expect(savedTask?.dueDateTime, dueDateTime);
    expect(savedTask?.completedAt, isNull);
    expect(savedReminder?.remindAt, reminder.remindAt);
    expect(savedReminder?.repeatRule, RepeatRule.none);
  });

  testWidgets('updates due date time without changing reminder',
      (tester) async {
    final now = DateTime(2026, 1, 1, 9);
    final originalDueDateTime = DateTime.now().add(const Duration(days: 1));
    final customDueDateTime = DateTime.now().add(const Duration(days: 2));
    final task = TaskItem(
      id: 'task-1',
      goalId: 'goal-1',
      title: '调整截止时间',
      priority: Priority.medium,
      status: TaskStatus.pending,
      estimatedMinutes: 30,
      dueDateTime: originalDueDateTime,
      createdAt: now,
      updatedAt: now,
    );
    final reminder = Reminder(
      id: 'reminder-1',
      targetType: ReminderTargetType.task,
      targetId: task.id,
      remindAt: originalDueDateTime.subtract(const Duration(hours: 1)),
      repeatRule: RepeatRule.none,
      enabled: true,
      createdAt: now,
      updatedAt: now,
    );
    TaskItem? savedTask;
    TaskReminderSelection? savedReminder;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskEditSheet(
            title: '编辑任务',
            task: task,
            reminder: reminder,
            customDueDateTimePicker: (_, __) async => customDueDateTime,
            onSave: (updatedTask, reminder) async {
              savedTask = updatedTask;
              savedReminder = reminder;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('点击调整日期和时间'));
    await tester.tap(find.text('点击调整日期和时间'));
    await tester.pumpAndSettle();

    final doneButton = find.ancestor(
      of: find.text('完成'),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(doneButton);
    await tester.tap(doneButton);
    await tester.pumpAndSettle();

    expect(savedTask?.dueDateTime, customDueDateTime);
    expect(savedReminder?.remindAt, reminder.remindAt);
    expect(savedReminder?.repeatRule, RepeatRule.none);
  });

  testWidgets('clears due date time without clearing reminder', (tester) async {
    final now = DateTime(2026, 1, 1, 9);
    final dueDateTime = DateTime.now().add(const Duration(days: 1));
    final task = TaskItem(
      id: 'task-1',
      goalId: 'goal-1',
      title: '清空截止时间',
      priority: Priority.medium,
      status: TaskStatus.pending,
      estimatedMinutes: 30,
      dueDateTime: dueDateTime,
      createdAt: now,
      updatedAt: now,
    );
    final reminder = Reminder(
      id: 'reminder-1',
      targetType: ReminderTargetType.task,
      targetId: task.id,
      remindAt: dueDateTime.subtract(const Duration(hours: 1)),
      repeatRule: RepeatRule.none,
      enabled: true,
      createdAt: now,
      updatedAt: now,
    );
    TaskItem? savedTask;
    TaskReminderSelection? savedReminder;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskEditSheet(
            title: '编辑任务',
            task: task,
            reminder: reminder,
            onSave: (updatedTask, reminder) async {
              savedTask = updatedTask;
              savedReminder = reminder;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('不设'));
    await tester.tap(find.text('不设'));
    await tester.pumpAndSettle();

    final doneButton = find.ancestor(
      of: find.text('完成'),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(doneButton);
    await tester.tap(doneButton);
    await tester.pumpAndSettle();

    expect(savedTask?.dueDateTime, isNull);
    expect(savedReminder?.remindAt, reminder.remindAt);
    expect(savedReminder?.repeatRule, RepeatRule.none);
  });
}

Finder _chipWithText(String text) {
  return find.ancestor(
    of: find.text(text),
    matching: find.byType(ChoiceChip),
  );
}

Goal _goal({
  required String id,
  required String title,
}) {
  final now = DateTime(2026, 1, 1);
  return Goal(
    id: id,
    title: title,
    type: GoalType.longTerm,
    priority: Priority.medium,
    status: GoalStatus.inProgress,
    startDate: now,
    createdAt: now,
    updatedAt: now,
  );
}
