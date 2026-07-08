import 'package:flutter/foundation.dart';
import 'package:evoly/core/constants/app_constants.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

class TodayController extends ChangeNotifier {
  TodayController(this.taskRepository);

  final TaskRepository taskRepository;

  var _tasks = <TaskItem>[];

  List<TaskItem> get tasks => List.unmodifiable(_tasks);

  List<TaskItem> get topTasks {
    final sorted = [..._tasks]..sort(
        (left, right) => right.priority.index.compareTo(left.priority.index),
      );

    return sorted.take(AppConstants.todayTopTaskLimit).toList();
  }

  Future<void> load(DateTime today) async {
    _tasks = await taskRepository.findPlanningCandidates(today);
    notifyListeners();
  }
}
