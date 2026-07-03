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

  Future<void> _save(AppSettings nextSettings) async {
    settings = nextSettings;
    notifyListeners();
    await repository.save(nextSettings);
  }
}
