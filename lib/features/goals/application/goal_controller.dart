import 'package:flutter/foundation.dart';
import 'package:evoly/features/goals/data/goal_repository.dart';
import 'package:evoly/features/goals/domain/goal.dart';

class GoalController extends ChangeNotifier {
  GoalController(this.repository);

  final GoalRepository repository;

  var _goals = <Goal>[];
  var _loading = false;

  List<Goal> get goals => List.unmodifiable(_goals);
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    _goals = await repository.findAll();

    _loading = false;
    notifyListeners();
  }

  Future<void> save(Goal goal) async {
    await repository.save(goal);
    await load();
  }
}
