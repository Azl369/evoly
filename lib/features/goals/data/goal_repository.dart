import 'package:evoly/features/goals/domain/goal.dart';

abstract class GoalRepository {
  Future<List<Goal>> findAll();

  Future<Goal?> findById(String id);

  Future<void> save(Goal goal);

  Future<void> delete(String id);
}

class InMemoryGoalRepository implements GoalRepository {
  final List<Goal> _goals = [];

  @override
  Future<List<Goal>> findAll() async {
    return List.unmodifiable(_goals);
  }

  @override
  Future<Goal?> findById(String id) async {
    for (final goal in _goals) {
      if (goal.id == id) {
        return goal;
      }
    }

    return null;
  }

  @override
  Future<void> save(Goal goal) async {
    final index = _goals.indexWhere((item) => item.id == goal.id);
    if (index == -1) {
      _goals.add(goal);
      return;
    }

    _goals[index] = goal;
  }

  @override
  Future<void> delete(String id) async {
    _goals.removeWhere((goal) => goal.id == id);
  }
}
