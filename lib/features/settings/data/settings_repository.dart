import 'package:flutter/material.dart';
import 'package:evoly/app/theme_preset.dart';
import 'package:evoly/core/constants/app_constants.dart';

class AppSettings {
  const AppSettings({
    required this.dailyReportEnabled,
    required this.defaultReminderHour,
    required this.defaultReminderMinute,
    required this.themeMode,
    required this.themePreset,
  });

  static const defaultSettings = AppSettings(
    dailyReportEnabled: true,
    defaultReminderHour: AppConstants.defaultReminderHour,
    defaultReminderMinute: AppConstants.defaultReminderMinute,
    themeMode: ThemeMode.system,
    themePreset: EvolyThemePreset.orbitBlue,
  );

  final bool dailyReportEnabled;
  final int defaultReminderHour;
  final int defaultReminderMinute;
  final ThemeMode themeMode;
  final EvolyThemePreset themePreset;

  AppSettings copyWith({
    bool? dailyReportEnabled,
    int? defaultReminderHour,
    int? defaultReminderMinute,
    ThemeMode? themeMode,
    EvolyThemePreset? themePreset,
  }) {
    return AppSettings(
      dailyReportEnabled: dailyReportEnabled ?? this.dailyReportEnabled,
      defaultReminderHour: defaultReminderHour ?? this.defaultReminderHour,
      defaultReminderMinute:
          defaultReminderMinute ?? this.defaultReminderMinute,
      themeMode: themeMode ?? this.themeMode,
      themePreset: themePreset ?? this.themePreset,
    );
  }
}

abstract class SettingsRepository {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}

extension ThemeModeInfo on ThemeMode {
  String get storageValue {
    return switch (this) {
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
    };
  }

  String get label {
    return switch (this) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };
  }
}

ThemeMode themeModeFromStorageValue(String? value) {
  return switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
