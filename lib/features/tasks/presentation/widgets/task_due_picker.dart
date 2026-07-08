import 'package:flutter/material.dart';
import 'package:evoly/shared/ui/components/app_components.dart';
import 'package:evoly/shared/ui/tokens/app_radii.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';

typedef TaskDueDateTimePicker = Future<DateTime?> Function(
  BuildContext context,
  DateTime initialDateTime,
);

enum TaskDueOption {
  today,
  tomorrow,
  custom,
  none,
}

class TaskDuePicker extends StatelessWidget {
  const TaskDuePicker({
    required this.dueDateTime,
    required this.onChanged,
    super.key,
    this.customPicker = showTaskDueDateTimePicker,
  });

  final DateTime? dueDateTime;
  final ValueChanged<DateTime?> onChanged;
  final TaskDueDateTimePicker customPicker;

  @override
  Widget build(BuildContext context) {
    final selectedOption = taskDueOptionFor(dueDateTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<TaskDueOption>(
            segments: const [
              ButtonSegment(
                value: TaskDueOption.today,
                icon: Icon(Icons.today_rounded),
                label: Text('今天'),
              ),
              ButtonSegment(
                value: TaskDueOption.tomorrow,
                icon: Icon(Icons.event_rounded),
                label: Text('明天'),
              ),
              ButtonSegment(
                value: TaskDueOption.custom,
                icon: Icon(Icons.edit_calendar_rounded),
                label: Text('自定义'),
              ),
              ButtonSegment(
                value: TaskDueOption.none,
                icon: Icon(Icons.event_busy_outlined),
                label: Text('不设'),
              ),
            ],
            selected: {selectedOption},
            onSelectionChanged: (values) {
              _handleSelection(context, values.first);
            },
          ),
        ),
        if (dueDateTime != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _DueSummaryRow(
            dueDateTime: dueDateTime!,
            onTap: () => _pickCustom(context),
          ),
        ],
      ],
    );
  }

  Future<void> _handleSelection(
    BuildContext context,
    TaskDueOption option,
  ) async {
    final now = DateTime.now();
    switch (option) {
      case TaskDueOption.today:
        onChanged(endOfToday(now));
      case TaskDueOption.tomorrow:
        onChanged(endOfTomorrow(now));
      case TaskDueOption.custom:
        await _pickCustom(context);
      case TaskDueOption.none:
        onChanged(null);
    }
  }

  Future<void> _pickCustom(BuildContext context) async {
    final selected = await customPicker(
      context,
      dueDateTime ?? endOfToday(DateTime.now()),
    );
    if (!context.mounted || selected == null) {
      return;
    }

    onChanged(selected);
  }
}

class _DueSummaryRow extends StatelessWidget {
  const _DueSummaryRow({
    required this.dueDateTime,
    required this.onTap,
  });

  final DateTime dueDateTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = EvolyDesignTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return AppSurface(
      variant: AppSurfaceVariant.muted,
      radius: AppRadii.element,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 20,
            color: tokens.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatTaskDueDateTime(dueDateTime),
                  style: textTheme.bodyLarge?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '点击调整日期和时间',
                  style: textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.keyboard_arrow_right_rounded,
            color: tokens.textSecondary,
          ),
        ],
      ),
    );
  }
}

Future<DateTime?> showTaskDueDateTimePicker(
  BuildContext context,
  DateTime initialDateTime,
) async {
  final now = DateTime.now();
  final firstDate = DateTime(now.year - 1, 1, 1);
  final lastDate = DateTime(now.year + 10, 12, 31);
  final normalizedInitialDate = initialDateTime.isBefore(firstDate)
      ? firstDate
      : initialDateTime.isAfter(lastDate)
          ? lastDate
          : initialDateTime;

  final selectedDate = await showDatePicker(
    context: context,
    initialDate: DateUtils.dateOnly(normalizedInitialDate),
    firstDate: firstDate,
    lastDate: lastDate,
  );
  if (!context.mounted || selectedDate == null) {
    return null;
  }

  final selectedTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initialDateTime),
  );
  if (selectedTime == null) {
    return null;
  }

  return DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    selectedTime.hour,
    selectedTime.minute,
  );
}

TaskDueOption taskDueOptionFor(DateTime? dueDateTime) {
  if (dueDateTime == null) {
    return TaskDueOption.none;
  }

  final now = DateTime.now();
  if (_isSameMinute(dueDateTime, endOfToday(now))) {
    return TaskDueOption.today;
  }
  if (_isSameMinute(dueDateTime, endOfTomorrow(now))) {
    return TaskDueOption.tomorrow;
  }

  return TaskDueOption.custom;
}

DateTime endOfToday(DateTime now) {
  return DateTime(now.year, now.month, now.day, 23, 59);
}

DateTime endOfTomorrow(DateTime now) {
  return endOfToday(now).add(const Duration(days: 1));
}

String formatTaskDueDateTime(
  DateTime dateTime, {
  DateTime? now,
  String prefix = '截止',
}) {
  final reference = now ?? DateTime.now();
  final dayLabel = _dayLabel(dateTime, reference);
  return '$prefix $dayLabel ${_formatClock(dateTime)}';
}

String _dayLabel(DateTime dateTime, DateTime now) {
  final date = DateUtils.dateOnly(dateTime);
  final today = DateUtils.dateOnly(now);
  final tomorrow = today.add(const Duration(days: 1));
  final yesterday = today.subtract(const Duration(days: 1));

  if (date == today) {
    return '今天';
  }
  if (date == tomorrow) {
    return '明天';
  }
  if (date == yesterday) {
    return '昨天';
  }
  if (date.year != today.year) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  return '${date.month}月${date.day}日';
}

String _formatClock(DateTime dateTime) {
  return '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';
}

bool _isSameMinute(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day &&
      left.hour == right.hour &&
      left.minute == right.minute;
}
