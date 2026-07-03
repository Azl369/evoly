import 'package:flutter/foundation.dart';

class DataRefreshController extends ChangeNotifier {
  var _revision = 0;

  int get revision => _revision;

  void markChanged() {
    _revision += 1;
    notifyListeners();
  }
}
