import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

abstract class TaskRepository {
  Future<TaskItem?> findById(String id);

  Future<List<TaskItem>> findByGoalId(String goalId);

  Future<List<TaskItem>> findDueToday(DateTime today);

  Future<List<TaskItem>> findPlanningCandidates(DateTime today);

  Future<List<TaskItem>> findCompletedToday(DateTime today);

  Future<void> save(TaskItem task);

  Future<void> reorderWithinPriority({
    required Priority priority,
    required List<String> orderedTaskIds,
  });

  Future<void> delete(String id);
}
