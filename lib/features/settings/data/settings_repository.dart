class AppSettings {
  const AppSettings({
    required this.dailyReportEnabled,
    required this.defaultReminderHour,
    required this.defaultReminderMinute,
  });

  final bool dailyReportEnabled;
  final int defaultReminderHour;
  final int defaultReminderMinute;
}

abstract class SettingsRepository {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}
