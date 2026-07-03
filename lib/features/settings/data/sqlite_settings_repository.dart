import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:evoly/app/theme_preset.dart';
import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/features/settings/data/settings_repository.dart';

class SqliteSettingsRepository implements SettingsRepository {
  const SqliteSettingsRepository(this.database);

  final AppDatabase database;

  static const _table = 'settings';
  static const _dailyReportEnabled = 'daily_report_enabled';
  static const _defaultReminderHour = 'default_reminder_hour';
  static const _defaultReminderMinute = 'default_reminder_minute';
  static const _themeMode = 'theme_mode';
  static const _themePreset = 'theme_preset';

  @override
  Future<AppSettings> load() async {
    final db = await database.database;
    final rows = await db.query(_table);
    final values = {
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
    const defaults = AppSettings.defaultSettings;

    return AppSettings(
      dailyReportEnabled: _readBool(
        values,
        _dailyReportEnabled,
        defaults.dailyReportEnabled,
      ),
      defaultReminderHour: _readInt(
        values,
        _defaultReminderHour,
        defaults.defaultReminderHour,
      ),
      defaultReminderMinute: _readInt(
        values,
        _defaultReminderMinute,
        defaults.defaultReminderMinute,
      ),
      themeMode: themeModeFromStorageValue(values[_themeMode]),
      themePreset: evolyThemePresetFromId(values[_themePreset]),
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final db = await database.database;
    final batch = db.batch();
    final values = <String, String>{
      _dailyReportEnabled: settings.dailyReportEnabled ? '1' : '0',
      _defaultReminderHour: settings.defaultReminderHour.toString(),
      _defaultReminderMinute: settings.defaultReminderMinute.toString(),
      _themeMode: settings.themeMode.storageValue,
      _themePreset: settings.themePreset.id,
    };

    for (final entry in values.entries) {
      batch.insert(
        _table,
        {
          'key': entry.key,
          'value': entry.value,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  bool _readBool(
    Map<String, String> values,
    String key,
    bool defaultValue,
  ) {
    final value = values[key];
    if (value == null) {
      return defaultValue;
    }

    return value == '1' || value == 'true';
  }

  int _readInt(
    Map<String, String> values,
    String key,
    int defaultValue,
  ) {
    return int.tryParse(values[key] ?? '') ?? defaultValue;
  }
}
