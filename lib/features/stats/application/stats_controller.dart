import 'package:flutter/foundation.dart';
import 'package:evoly/features/stats/data/stats_repository.dart';

class StatsController extends ChangeNotifier {
  StatsController(this.repository);

  final StatsRepository repository;

  StatsSnapshot? _snapshot;

  StatsSnapshot? get snapshot => _snapshot;

  Future<void> load() async {
    _snapshot = await repository.loadWeeklySnapshot();
    notifyListeners();
  }
}
