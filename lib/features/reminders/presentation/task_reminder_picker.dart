import 'package:flutter/material.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';

enum ReminderOption {
  today,
  tomorrow,
  weekly,
  monthly,
  none,
}

class TaskReminderSelection {
  const TaskReminderSelection({
    required this.remindAt,
    required this.repeatRule,
  });

  static const none = TaskReminderSelection(
    remindAt: null,
    repeatRule: RepeatRule.none,
  );

  factory TaskReminderSelection.fromReminder(Reminder? reminder) {
    if (reminder == null) {
      return TaskReminderSelection.none;
    }

    return TaskReminderSelection(
      remindAt: reminder.remindAt,
      repeatRule: reminder.repeatRule,
    );
  }

  final DateTime? remindAt;
  final RepeatRule repeatRule;

  bool get enabled => remindAt != null;
}

class TaskReminderPicker extends StatelessWidget {
  const TaskReminderPicker({
    required this.selection,
    required this.onChanged,
    super.key,
  });

  final TaskReminderSelection selection;
  final ValueChanged<TaskReminderSelection> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedOption = _optionFor(selection);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in ReminderOption.values)
          ChoiceChip(
            selected: selectedOption == option,
            showCheckmark: false,
            avatar: Icon(_iconFor(option), size: 18),
            label: Text(_labelFor(option)),
            onSelected: (_) => onChanged(
              _selectionFor(option, DateTime.now()),
            ),
          ),
      ],
    );
  }
}

ReminderOption reminderOptionFor(Reminder? reminder) {
  return _optionFor(TaskReminderSelection.fromReminder(reminder));
}

ReminderOption _optionFor(TaskReminderSelection selection) {
  if (selection.repeatRule == RepeatRule.weekly) {
    return ReminderOption.weekly;
  }

  if (selection.repeatRule == RepeatRule.monthly) {
    return ReminderOption.monthly;
  }

  final remindAt = selection.remindAt;
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

TaskReminderSelection _selectionFor(ReminderOption option, DateTime now) {
  final todayReminder = DateTime(now.year, now.month, now.day, 20);

  return switch (option) {
    ReminderOption.today => TaskReminderSelection(
        remindAt: todayReminder.isAfter(now)
            ? todayReminder
            : now.add(const Duration(minutes: 1)),
        repeatRule: RepeatRule.none,
      ),
    ReminderOption.tomorrow => TaskReminderSelection(
        remindAt: todayReminder.add(const Duration(days: 1)),
        repeatRule: RepeatRule.none,
      ),
    ReminderOption.weekly => TaskReminderSelection(
        remindAt: RepeatRule.weekly.nextOccurrenceAfter(todayReminder, now) ??
            todayReminder,
        repeatRule: RepeatRule.weekly,
      ),
    ReminderOption.monthly => TaskReminderSelection(
        remindAt: RepeatRule.monthly.nextOccurrenceAfter(todayReminder, now) ??
            todayReminder,
        repeatRule: RepeatRule.monthly,
      ),
    ReminderOption.none => TaskReminderSelection.none,
  };
}

String _labelFor(ReminderOption option) {
  return switch (option) {
    ReminderOption.today => '今天提醒',
    ReminderOption.tomorrow => '明天提醒',
    ReminderOption.weekly => '每周提醒',
    ReminderOption.monthly => '每月提醒',
    ReminderOption.none => '不提醒',
  };
}

IconData _iconFor(ReminderOption option) {
  return switch (option) {
    ReminderOption.today => Icons.today_rounded,
    ReminderOption.tomorrow => Icons.event_rounded,
    ReminderOption.weekly => Icons.event_repeat_rounded,
    ReminderOption.monthly => Icons.calendar_month_rounded,
    ReminderOption.none => Icons.notifications_off_outlined,
  };
}
