import 'package:flutter_test/flutter_test.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/tasks/application/task_recurrence_service.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

void main() {
  test('completes weekly task and creates next occurrence', () async {
    final now = DateTime(2026, 7, 8, 20);
    final dueDateTime = DateTime(2026, 7, 8, 20);
    final repository = _FakeTaskRepository([
      _task(
        id: 'weekly',
        now: now,
        dueDateTime: dueDateTime,
        repeatRule: TaskRepeatRule.weekly,
        repeatSeriesId: 'series-1',
      ),
    ]);
    final service = TaskRecurrenceService(repository);

    final result = await service.complete(repository.tasks.single, now);

    expect(result.completedTask.status, TaskStatus.completed);
    expect(result.nextTask, isNotNull);
    expect(
      result.nextTask?.dueDateTime,
      dueDateTime.add(const Duration(days: 7)),
    );
    expect(result.nextTask?.repeatRule, TaskRepeatRule.weekly);
    expect(result.nextTask?.repeatSeriesId, 'series-1');
    expect(repository.tasks, hasLength(2));
  });

  test('does not create duplicate next occurrence', () async {
    final now = DateTime(2026, 7, 8, 20);
    final dueDateTime = DateTime(2026, 7, 8, 20);
    final nextDueDateTime = dueDateTime.add(const Duration(days: 7));
    final repository = _FakeTaskRepository([
      _task(
        id: 'weekly',
        now: now,
        dueDateTime: dueDateTime,
        repeatRule: TaskRepeatRule.weekly,
        repeatSeriesId: 'series-1',
      ),
      _task(
        id: 'weekly-next',
        now: now,
        dueDateTime: nextDueDateTime,
        repeatRule: TaskRepeatRule.weekly,
        repeatSeriesId: 'series-1',
      ),
    ]);
    final service = TaskRecurrenceService(repository);

    final result = await service.complete(repository.tasks.first, now);

    expect(result.nextTask, isNull);
    expect(repository.tasks, hasLength(2));
  });

  test('does not create next occurrence for non-repeating task', () async {
    final now = DateTime(2026, 7, 8, 20);
    final repository = _FakeTaskRepository([
      _task(
        id: 'one-off',
        now: now,
        dueDateTime: now,
      ),
    ]);
    final service = TaskRecurrenceService(repository);

    final result = await service.complete(repository.tasks.single, now);

    expect(result.nextTask, isNull);
    expect(repository.tasks, hasLength(1));
    expect(repository.tasks.single.status, TaskStatus.completed);
  });
}

TaskItem _task({
  required String id,
  required DateTime now,
  DateTime? dueDateTime,
  TaskRepeatRule repeatRule = TaskRepeatRule.none,
  String? repeatSeriesId,
}) {
  return TaskItem(
    id: id,
    goalId: 'goal-1',
    title: '每周复盘',
    priority: Priority.medium,
    status: TaskStatus.pending,
    estimatedMinutes: 30,
    dueDateTime: dueDateTime,
    createdAt: now,
    updatedAt: now,
    repeatRule: repeatRule,
    repeatSeriesId: repeatSeriesId,
  );
}

class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository(this.tasks);

  final List<TaskItem> tasks;

  @override
  Future<void> delete(String id) async {
    tasks.removeWhere((task) => task.id == id);
  }

  @override
  Future<TaskItem?> findById(String id) async {
    return tasks.where((task) => task.id == id).firstOrNull;
  }

  @override
  Future<List<TaskItem>> findByGoalId(String goalId) async {
    return tasks.where((task) => task.goalId == goalId).toList();
  }

  @override
  Future<List<TaskItem>> findDueToday(DateTime today) async => tasks;

  @override
  Future<List<TaskItem>> findPlanningCandidates(DateTime today) async => tasks;

  @override
  Future<List<TaskItem>> findCompletedToday(DateTime today) async {
    return tasks.where((task) => task.status == TaskStatus.completed).toList();
  }

  @override
  Future<TaskItem?> findRepeatOccurrence({
    required String repeatSeriesId,
    required DateTime dueDateTime,
  }) async {
    return tasks.where((task) {
      return task.repeatSeriesId == repeatSeriesId &&
          task.dueDateTime == dueDateTime;
    }).firstOrNull;
  }

  @override
  Future<void> save(TaskItem task) async {
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index == -1) {
      tasks.add(task);
    } else {
      tasks[index] = task;
    }
  }

  @override
  Future<void> reorderWithinPriority({
    required Priority priority,
    required List<String> orderedTaskIds,
  }) async {}
}
