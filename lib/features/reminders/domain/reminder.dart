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
}
