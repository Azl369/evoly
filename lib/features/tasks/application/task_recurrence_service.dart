import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';
import 'package:uuid/uuid.dart';

class TaskCompletionResult {
  const TaskCompletionResult({
    required this.completedTask,
    this.nextTask,
  });

  final TaskItem completedTask;
  final TaskItem? nextTask;
}

class TaskRecurrenceService {
  const TaskRecurrenceService(
    this.taskRepository, {
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final TaskRepository taskRepository;
  final Uuid _uuid;

  Future<TaskCompletionResult> complete(TaskItem task, DateTime now) async {
    final completedTask = task.copyWith(
      status: TaskStatus.completed,
      completedAt: now,
      updatedAt: now,
    );
    await taskRepository.save(completedTask);

    final nextTask = await _createNextWeeklyTaskIfNeeded(completedTask, now);
    return TaskCompletionResult(
      completedTask: completedTask,
      nextTask: nextTask,
    );
  }

  Future<TaskItem?> _createNextWeeklyTaskIfNeeded(
    TaskItem completedTask,
    DateTime now,
  ) async {
    if (completedTask.repeatRule != TaskRepeatRule.weekly) {
      return null;
    }

    final dueDateTime = completedTask.dueDateTime;
    if (dueDateTime == null) {
      return null;
    }

    final repeatSeriesId = completedTask.repeatSeriesId ?? completedTask.id;
    final nextDueDateTime = dueDateTime.add(const Duration(days: 7));
    final existing = await taskRepository.findRepeatOccurrence(
      repeatSeriesId: repeatSeriesId,
      dueDateTime: nextDueDateTime,
    );
    if (existing != null) {
      return null;
    }

    final nextTask = TaskItem(
      id: _uuid.v4(),
      goalId: completedTask.goalId,
      title: completedTask.title,
      description: completedTask.description,
      priority: completedTask.priority,
      status: TaskStatus.pending,
      estimatedMinutes: completedTask.estimatedMinutes,
      dueDateTime: nextDueDateTime,
      createdAt: now,
      updatedAt: now,
      sortOrder: completedTask.sortOrder,
      repeatRule: completedTask.repeatRule,
      repeatSeriesId: repeatSeriesId,
    );
    await taskRepository.save(nextTask);
    return nextTask;
  }
}
