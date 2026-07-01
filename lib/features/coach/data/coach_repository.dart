import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

abstract interface class CoachRepository {
  Future<CoachTodayContext> loadTodayContext(DateTime now);
}

class CoachTodayContext {
  const CoachTodayContext({
    required this.todayTasks,
    required this.delayedGoalStats,
  });

  final List<CoachTaskContext> todayTasks;
  final List<CoachDelayedGoalStat> delayedGoalStats;
}

class CoachTaskContext {
  const CoachTaskContext({
    required this.id,
    required this.goalId,
    required this.title,
    required this.priority,
    required this.status,
    required this.estimatedMinutes,
    required this.goalTitle,
    this.dueDateTime,
    this.completedAt,
  });

  final String id;
  final String goalId;
  final String title;
  final Priority priority;
  final TaskStatus status;
  final int estimatedMinutes;
  final String goalTitle;
  final DateTime? dueDateTime;
  final DateTime? completedAt;

  bool get isCompleted => status == TaskStatus.completed;
}

class CoachDelayedGoalStat {
  const CoachDelayedGoalStat({
    required this.goalId,
    required this.goalTitle,
    required this.postponedTaskCount,
    required this.latestPostponedAt,
  });

  final String goalId;
  final String goalTitle;
  final int postponedTaskCount;
  final DateTime latestPostponedAt;
}
