class StatsSnapshot {
  const StatsSnapshot({
    required this.todayCompletedTasks,
    required this.weekCompletedTasks,
    required this.todayPostponedTasks,
    required this.weekPostponedTasks,
    required this.goalCompletionRate,
    required this.streakDays,
    required this.totalGoals,
    required this.completedGoals,
    required this.todayCompletedItems,
    required this.weekCompletedItems,
    required this.todayPostponedItems,
    required this.weekPostponedItems,
  });

  final int todayCompletedTasks;
  final int weekCompletedTasks;
  final int todayPostponedTasks;
  final int weekPostponedTasks;
  final double goalCompletionRate;
  final int streakDays;
  final int totalGoals;
  final int completedGoals;
  final List<StatsTaskItem> todayCompletedItems;
  final List<StatsTaskItem> weekCompletedItems;
  final List<StatsTaskItem> todayPostponedItems;
  final List<StatsTaskItem> weekPostponedItems;
}

abstract class StatsRepository {
  Future<StatsSnapshot> loadWeeklySnapshot();
}

class StatsTaskItem {
  const StatsTaskItem({
    required this.id,
    required this.title,
    required this.occurredAt,
    required this.estimatedMinutes,
  });

  final String id;
  final String title;
  final DateTime occurredAt;
  final int estimatedMinutes;
}
