import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evoly/features/reminders/presentation/task_reminder_picker.dart';
import 'package:evoly/features/tasks/presentation/widgets/task_create_sheet.dart';

void main() {
  testWidgets('creates task with today 23:59 as default due time',
      (tester) async {
    _CreatedTask? createdTask;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCreateSheet(
            onCreate: (title, estimatedMinutes, dueDateTime, reminder) async {
              createdTask = _CreatedTask(
                title: title,
                estimatedMinutes: estimatedMinutes,
                dueDateTime: dueDateTime,
                reminder: reminder,
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('预计耗时（分钟）'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '默认截止任务');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    final dueDateTime = createdTask?.dueDateTime;
    final now = DateTime.now();
    expect(createdTask?.title, '默认截止任务');
    expect(createdTask?.estimatedMinutes, 30);
    expect(dueDateTime, isNotNull);
    expect(dueDateTime?.year, now.year);
    expect(dueDateTime?.month, now.month);
    expect(dueDateTime?.day, now.day);
    expect(dueDateTime?.hour, 23);
    expect(dueDateTime?.minute, 59);
  });

  testWidgets('creates task with custom tomorrow time', (tester) async {
    final now = DateTime.now();
    final customDueDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      10,
    ).add(const Duration(days: 1));
    _CreatedTask? createdTask;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCreateSheet(
            customDueDateTimePicker: (_, __) async => customDueDateTime,
            onCreate: (title, estimatedMinutes, dueDateTime, reminder) async {
              createdTask = _CreatedTask(
                title: title,
                estimatedMinutes: estimatedMinutes,
                dueDateTime: dueDateTime,
                reminder: reminder,
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '明天具体时间任务');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(createdTask?.dueDateTime, customDueDateTime);
    expect(createdTask?.reminder, TaskReminderSelection.none);
  });
}

class _CreatedTask {
  const _CreatedTask({
    required this.title,
    required this.estimatedMinutes,
    required this.dueDateTime,
    required this.reminder,
  });

  final String title;
  final int estimatedMinutes;
  final DateTime? dueDateTime;
  final TaskReminderSelection reminder;
}
