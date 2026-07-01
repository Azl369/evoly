import 'package:evoly/core/domain/priority.dart';

enum CoachInsightStatus {
  empty,
  normal,
  overloaded,
  delayRisk,
  completed,
}

enum CoachSuggestionType {
  focus,
  reduce,
  delayRisk,
  empty,
  celebration,
}

enum CoachSuggestionSeverity {
  info,
  warning,
  success,
}

class CoachInsight {
  const CoachInsight({
    required this.status,
    required this.summary,
    required this.pendingTaskCount,
    required this.completedTaskCount,
    required this.totalEstimatedMinutes,
    required this.topTasks,
    required this.delayedGoals,
    required this.suggestions,
    this.overloadedByCount = false,
    this.overloadedByTime = false,
  });

  final CoachInsightStatus status;
  final String summary;
  final int pendingTaskCount;
  final int completedTaskCount;
  final int totalEstimatedMinutes;
  final bool overloadedByCount;
  final bool overloadedByTime;
  final List<CoachTopTask> topTasks;
  final List<CoachDelayedGoal> delayedGoals;
  final List<CoachSuggestion> suggestions;

  bool get isEmpty => status == CoachInsightStatus.empty;
}

class CoachTopTask {
  const CoachTopTask({
    required this.id,
    required this.title,
    required this.priority,
    required this.goalTitle,
    required this.reason,
    this.dueDateTime,
  });

  final String id;
  final String title;
  final Priority priority;
  final String goalTitle;
  final String reason;
  final DateTime? dueDateTime;
}

class CoachDelayedGoal {
  const CoachDelayedGoal({
    required this.id,
    required this.title,
    required this.postponedTaskCount,
    required this.latestPostponedAt,
  });

  final String id;
  final String title;
  final int postponedTaskCount;
  final DateTime latestPostponedAt;
}

class CoachSuggestion {
  const CoachSuggestion({
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
  });

  final CoachSuggestionType type;
  final CoachSuggestionSeverity severity;
  final String title;
  final String description;
}
