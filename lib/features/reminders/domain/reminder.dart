import 'dart:math' as math;

enum ReminderTargetType {
  goal,
  task,
}

enum RepeatRule {
  none,
  daily,
  weekly,
  monthly,
  custom,
}

class Reminder {
  const Reminder({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.remindAt,
    required this.repeatRule,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.advanceMinutes = 0,
    this.firedAt,
  });

  final String id;
  final ReminderTargetType targetType;
  final String targetId;
  final DateTime remindAt;
  final RepeatRule repeatRule;
  final int advanceMinutes;
  final bool enabled;
  final DateTime? firedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Reminder copyWith({
    DateTime? remindAt,
    RepeatRule? repeatRule,
    int? advanceMinutes,
    bool? enabled,
    DateTime? firedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearFiredAt = false,
  }) {
    return Reminder(
      id: id,
      targetType: targetType,
      targetId: targetId,
      remindAt: remindAt ?? this.remindAt,
      repeatRule: repeatRule ?? this.repeatRule,
      advanceMinutes: advanceMinutes ?? this.advanceMinutes,
      enabled: enabled ?? this.enabled,
      firedAt: clearFiredAt ? null : firedAt ?? this.firedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

extension RepeatRuleSchedule on RepeatRule {
  bool get isRepeating {
    return switch (this) {
      RepeatRule.daily || RepeatRule.weekly || RepeatRule.monthly => true,
      RepeatRule.none || RepeatRule.custom => false,
    };
  }

  DateTime? nextOccurrenceAfter(DateTime occurrence, DateTime after) {
    if (!isRepeating) {
      return null;
    }

    var next = occurrence;
    while (!next.isAfter(after)) {
      next = switch (this) {
        RepeatRule.daily => next.add(const Duration(days: 1)),
        RepeatRule.weekly => next.add(const Duration(days: 7)),
        RepeatRule.monthly => _addMonths(next, 1),
        RepeatRule.none || RepeatRule.custom => next,
      };
    }
    return next;
  }
}

DateTime _addMonths(DateTime value, int months) {
  final targetMonthIndex = value.month + months - 1;
  final year = value.year + targetMonthIndex ~/ 12;
  final month = targetMonthIndex % 12 + 1;
  final lastDayOfTargetMonth = DateTime(year, month + 1, 0).day;
  final day = math.min(value.day, lastDayOfTargetMonth);

  return DateTime(
    year,
    month,
    day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}
