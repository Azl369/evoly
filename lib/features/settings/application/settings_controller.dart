import 'package:flutter/foundation.dart';
import 'package:evoly/core/constants/app_constants.dart';
import 'package:evoly/features/settings/data/settings_repository.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this.repository);

  final SettingsRepository repository;

  AppSettings settings = const AppSettings(
    dailyReportEnabled: true,
    defaultReminderHour: AppConstants.defaultReminderHour,
    defaultReminderMinute: AppConstants.defaultReminderMinute,
  );

  Future<void> load() async {
    settings = await repository.load();
    notifyListeners();
  }
}
