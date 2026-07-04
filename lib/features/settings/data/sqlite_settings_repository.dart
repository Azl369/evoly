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
  static const _windowsCloseBehavior = 'windows_close_behavior';
  static const _windowsTrayClickBehavior = 'windows_tray_click_behavior';
  static const _windowsCompactAlwaysOnTop = 'windows_compact_always_on_top';
  static const _windowsCompactPositionX = 'windows_compact_position_x';
  static const _windowsCompactPositionY = 'windows_compact_position_y';
  static const _windowsReminderPauseUntil = 'windows_reminder_pause_until';

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
      windowsCloseBehavior: windowsCloseBehaviorFromStorageValue(
        values[_windowsCloseBehavior],
      ),
      windowsTrayClickBehavior: windowsTrayClickBehaviorFromStorageValue(
        values[_windowsTrayClickBehavior],
      ),
      windowsCompactAlwaysOnTop: _readBool(
        values,
        _windowsCompactAlwaysOnTop,
        defaults.windowsCompactAlwaysOnTop,
      ),
      windowsCompactPositionX: _readDouble(
        values,
        _windowsCompactPositionX,
      ),
      windowsCompactPositionY: _readDouble(
        values,
        _windowsCompactPositionY,
      ),
      windowsReminderPauseUntil: _readDateTime(
        values,
        _windowsReminderPauseUntil,
      ),
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final db = await database.database;
    final batch = db.batch();
    final values = <String, String?>{
      _dailyReportEnabled: settings.dailyReportEnabled ? '1' : '0',
      _defaultReminderHour: settings.defaultReminderHour.toString(),
      _defaultReminderMinute: settings.defaultReminderMinute.toString(),
      _themeMode: settings.themeMode.storageValue,
      _themePreset: settings.themePreset.id,
      _windowsCloseBehavior: settings.windowsCloseBehavior.storageValue,
      _windowsTrayClickBehavior: settings.windowsTrayClickBehavior.storageValue,
      _windowsCompactAlwaysOnTop:
          settings.windowsCompactAlwaysOnTop ? '1' : '0',
      _windowsCompactPositionX: settings.windowsCompactPositionX?.toString(),
      _windowsCompactPositionY: settings.windowsCompactPositionY?.toString(),
      _windowsReminderPauseUntil:
          settings.windowsReminderPauseUntil?.millisecondsSinceEpoch.toString(),
    };

    for (final entry in values.entries) {
      final value = entry.value;
      if (value == null) {
        batch.delete(
          _table,
          where: 'key = ?',
          whereArgs: [entry.key],
        );
        continue;
      }

      batch.insert(
        _table,
        {
          'key': entry.key,
          'value': value,
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

  double? _readDouble(
    Map<String, String> values,
    String key,
  ) {
    return double.tryParse(values[key] ?? '');
  }

  DateTime? _readDateTime(
    Map<String, String> values,
    String key,
  ) {
    final milliseconds = int.tryParse(values[key] ?? '');
    if (milliseconds == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
}
