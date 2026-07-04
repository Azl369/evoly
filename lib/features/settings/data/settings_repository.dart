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
    required this.windowsCloseBehavior,
    required this.windowsTrayClickBehavior,
    required this.windowsCompactAlwaysOnTop,
    this.windowsCompactPositionX,
    this.windowsCompactPositionY,
    this.windowsReminderPauseUntil,
  });

  static const defaultSettings = AppSettings(
    dailyReportEnabled: true,
    defaultReminderHour: AppConstants.defaultReminderHour,
    defaultReminderMinute: AppConstants.defaultReminderMinute,
    themeMode: ThemeMode.system,
    themePreset: EvolyThemePreset.orbitBlue,
    windowsCloseBehavior: WindowsCloseBehavior.hideToTray,
    windowsTrayClickBehavior: WindowsTrayClickBehavior.showCompact,
    windowsCompactAlwaysOnTop: true,
  );

  static const Object _unchanged = Object();

  final bool dailyReportEnabled;
  final int defaultReminderHour;
  final int defaultReminderMinute;
  final ThemeMode themeMode;
  final EvolyThemePreset themePreset;
  final WindowsCloseBehavior windowsCloseBehavior;
  final WindowsTrayClickBehavior windowsTrayClickBehavior;
  final bool windowsCompactAlwaysOnTop;
  final double? windowsCompactPositionX;
  final double? windowsCompactPositionY;
  final DateTime? windowsReminderPauseUntil;

  Offset? get windowsCompactPosition {
    final x = windowsCompactPositionX;
    final y = windowsCompactPositionY;
    if (x == null || y == null) {
      return null;
    }

    return Offset(x, y);
  }

  bool windowsRemindersPaused(DateTime now) {
    final pauseUntil = windowsReminderPauseUntil;
    return pauseUntil != null && pauseUntil.isAfter(now);
  }

  AppSettings copyWith({
    bool? dailyReportEnabled,
    int? defaultReminderHour,
    int? defaultReminderMinute,
    ThemeMode? themeMode,
    EvolyThemePreset? themePreset,
    WindowsCloseBehavior? windowsCloseBehavior,
    WindowsTrayClickBehavior? windowsTrayClickBehavior,
    bool? windowsCompactAlwaysOnTop,
    Object? windowsCompactPositionX = _unchanged,
    Object? windowsCompactPositionY = _unchanged,
    Object? windowsReminderPauseUntil = _unchanged,
  }) {
    return AppSettings(
      dailyReportEnabled: dailyReportEnabled ?? this.dailyReportEnabled,
      defaultReminderHour: defaultReminderHour ?? this.defaultReminderHour,
      defaultReminderMinute:
          defaultReminderMinute ?? this.defaultReminderMinute,
      themeMode: themeMode ?? this.themeMode,
      themePreset: themePreset ?? this.themePreset,
      windowsCloseBehavior: windowsCloseBehavior ?? this.windowsCloseBehavior,
      windowsTrayClickBehavior:
          windowsTrayClickBehavior ?? this.windowsTrayClickBehavior,
      windowsCompactAlwaysOnTop:
          windowsCompactAlwaysOnTop ?? this.windowsCompactAlwaysOnTop,
      windowsCompactPositionX: identical(windowsCompactPositionX, _unchanged)
          ? this.windowsCompactPositionX
          : (windowsCompactPositionX as num?)?.toDouble(),
      windowsCompactPositionY: identical(windowsCompactPositionY, _unchanged)
          ? this.windowsCompactPositionY
          : (windowsCompactPositionY as num?)?.toDouble(),
      windowsReminderPauseUntil:
          identical(windowsReminderPauseUntil, _unchanged)
              ? this.windowsReminderPauseUntil
              : windowsReminderPauseUntil as DateTime?,
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

enum WindowsCloseBehavior {
  hideToTray,
  showCompact,
  exitApp,
}

extension WindowsCloseBehaviorInfo on WindowsCloseBehavior {
  String get storageValue {
    return switch (this) {
      WindowsCloseBehavior.hideToTray => 'hide_to_tray',
      WindowsCloseBehavior.showCompact => 'show_compact',
      WindowsCloseBehavior.exitApp => 'exit_app',
    };
  }

  String get label {
    return switch (this) {
      WindowsCloseBehavior.hideToTray => '隐藏到托盘',
      WindowsCloseBehavior.showCompact => '切到迷你面板',
      WindowsCloseBehavior.exitApp => '退出应用',
    };
  }
}

WindowsCloseBehavior windowsCloseBehaviorFromStorageValue(String? value) {
  return switch (value) {
    'show_compact' => WindowsCloseBehavior.showCompact,
    'exit_app' => WindowsCloseBehavior.exitApp,
    _ => WindowsCloseBehavior.hideToTray,
  };
}

enum WindowsTrayClickBehavior {
  showCompact,
  openFull,
}

extension WindowsTrayClickBehaviorInfo on WindowsTrayClickBehavior {
  String get storageValue {
    return switch (this) {
      WindowsTrayClickBehavior.showCompact => 'show_compact',
      WindowsTrayClickBehavior.openFull => 'open_full',
    };
  }

  String get label {
    return switch (this) {
      WindowsTrayClickBehavior.showCompact => '显示迷你面板',
      WindowsTrayClickBehavior.openFull => '打开完整模式',
    };
  }
}

WindowsTrayClickBehavior windowsTrayClickBehaviorFromStorageValue(
  String? value,
) {
  return switch (value) {
    'open_full' => WindowsTrayClickBehavior.openFull,
    _ => WindowsTrayClickBehavior.showCompact,
  };
}
