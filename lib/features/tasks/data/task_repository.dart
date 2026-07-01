import 'package:evoly/features/tasks/domain/task_item.dart';

abstract class TaskRepository {
  Future<TaskItem?> findById(String id);

  Future<List<TaskItem>> findByGoalId(String goalId);

  Future<List<TaskItem>> findDueToday(DateTime today);

  Future<void> save(TaskItem task);

  Future<void> delete(String id);
}
