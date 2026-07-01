import 'package:evoly/core/domain/priority.dart';

enum GoalType {
  oneTime,
  recurring,
  longTerm,
}

enum GoalStatus {
  notStarted,
  inProgress,
  completed,
  paused,
  abandoned,
}

extension GoalStatusLabel on GoalStatus {
  String get label {
    return switch (this) {
      GoalStatus.notStarted => '未开始',
      GoalStatus.inProgress => '进行中',
      GoalStatus.completed => '已完成',
      GoalStatus.paused => '已暂停',
      GoalStatus.abandoned => '已放弃',
    };
  }
}

class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.type,
    required this.priority,
    required this.status,
    required this.startDate,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.dueDate,
    this.progress = 0,
  });

  final String id;
  final String title;
  final String description;
  final GoalType type;
  final Priority priority;
  final GoalStatus status;
  final DateTime startDate;
  final DateTime? dueDate;
  final double progress;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive {
    return status == GoalStatus.notStarted || status == GoalStatus.inProgress;
  }

  double get normalizedProgress => progress.clamp(0.0, 1.0).toDouble();

  Goal copyWith({
    String? title,
    String? description,
    GoalType? type,
    Priority? priority,
    GoalStatus? status,
    DateTime? startDate,
    DateTime? dueDate,
    double? progress,
    DateTime? updatedAt,
  }) {
    return Goal(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      progress: progress ?? this.progress,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
