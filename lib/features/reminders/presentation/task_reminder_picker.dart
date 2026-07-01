import 'package:flutter/material.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';

enum ReminderOption {
  today,
  tomorrow,
  none,
}

class TaskReminderPicker extends StatelessWidget {
  const TaskReminderPicker({
    required this.selectedRemindAt,
    required this.onChanged,
    super.key,
  });

  final DateTime? selectedRemindAt;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ReminderOption>(
      segments: const [
        ButtonSegment(value: ReminderOption.today, label: Text('今天提醒')),
        ButtonSegment(value: ReminderOption.tomorrow, label: Text('明天提醒')),
        ButtonSegment(value: ReminderOption.none, label: Text('不提醒')),
      ],
      selected: {_optionFor(selectedRemindAt)},
      onSelectionChanged: (values) {
        final option = values.first;
        final now = DateTime.now();
        final todayReminder = DateTime(now.year, now.month, now.day, 20);

        onChanged(
          switch (option) {
            ReminderOption.today => todayReminder.isAfter(now)
                ? todayReminder
                : now.add(const Duration(minutes: 1)),
            ReminderOption.tomorrow =>
              todayReminder.add(const Duration(days: 1)),
            ReminderOption.none => null,
          },
        );
      },
    );
  }
}

ReminderOption reminderOptionFor(Reminder? reminder) {
  return _optionFor(reminder?.remindAt);
}

ReminderOption _optionFor(DateTime? remindAt) {
  if (remindAt == null) {
    return ReminderOption.none;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(remindAt.year, remindAt.month, remindAt.day);
  if (target == today) {
    return ReminderOption.today;
  }

  return ReminderOption.tomorrow;
}
