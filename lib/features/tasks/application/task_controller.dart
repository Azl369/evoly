import 'package:flutter/foundation.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

class TaskController extends ChangeNotifier {
  TaskController(this.repository);

  final TaskRepository repository;

  Future<void> complete(TaskItem task, DateTime now) async {
    await repository.save(
      task.copyWith(
        status: TaskStatus.completed,
        completedAt: now,
        updatedAt: now,
      ),
    );

    notifyListeners();
  }
}
