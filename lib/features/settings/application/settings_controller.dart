import 'package:flutter/material.dart';
import 'package:evoly/app/theme_preset.dart';
import 'package:evoly/features/settings/data/settings_repository.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this.repository);

  final SettingsRepository repository;

  AppSettings settings = AppSettings.defaultSettings;

  Future<void> load() async {
    settings = await repository.load();
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode themeMode) async {
    if (settings.themeMode == themeMode) {
      return;
    }

    await _save(settings.copyWith(themeMode: themeMode));
  }

  Future<void> updateThemePreset(EvolyThemePreset themePreset) async {
    if (settings.themePreset == themePreset) {
      return;
    }

    await _save(settings.copyWith(themePreset: themePreset));
  }

  Future<void> updateWindowsCloseBehavior(
    WindowsCloseBehavior behavior,
  ) async {
    if (settings.windowsCloseBehavior == behavior) {
      return;
    }

    await _save(settings.copyWith(windowsCloseBehavior: behavior));
  }

  Future<void> updateWindowsTrayClickBehavior(
    WindowsTrayClickBehavior behavior,
  ) async {
    if (settings.windowsTrayClickBehavior == behavior) {
      return;
    }

    await _save(settings.copyWith(windowsTrayClickBehavior: behavior));
  }

  Future<void> updateWindowsCompactAlwaysOnTop(bool alwaysOnTop) async {
    if (settings.windowsCompactAlwaysOnTop == alwaysOnTop) {
      return;
    }

    await _save(
      settings.copyWith(windowsCompactAlwaysOnTop: alwaysOnTop),
    );
  }

  Future<void> updateWindowsCompactPosition(Offset? position) async {
    final nextSettings = settings.copyWith(
      windowsCompactPositionX: position?.dx,
      windowsCompactPositionY: position?.dy,
    );
    if (settings.windowsCompactPosition ==
        nextSettings.windowsCompactPosition) {
      return;
    }

    await _save(nextSettings);
  }

  Future<void> pauseWindowsRemindersFor(Duration duration) async {
    await _save(
      settings.copyWith(
        windowsReminderPauseUntil: DateTime.now().add(duration),
      ),
    );
  }

  Future<void> resumeWindowsReminders() async {
    if (settings.windowsReminderPauseUntil == null) {
      return;
    }

    await _save(settings.copyWith(windowsReminderPauseUntil: null));
  }

  Future<void> _save(AppSettings nextSettings) async {
    settings = nextSettings;
    notifyListeners();
    await repository.save(nextSettings);
  }
}
