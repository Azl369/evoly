import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/features/settings/data/settings_repository.dart';
import 'package:evoly/features/settings/data/sqlite_settings_repository.dart';

void main() {
  test('persists Windows desktop settings and clears compact position',
      () async {
    final directory = await Directory.systemTemp.createTemp('evoly-settings-');
    final database = AppDatabase.testing(p.join(directory.path, 'evoly.db'));
    final repository = SqliteSettingsRepository(database);
    addTearDown(() async {
      await database.close();
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });

    final defaults = await repository.load();
    expect(defaults.windowsCloseBehavior, WindowsCloseBehavior.hideToTray);
    expect(defaults.windowsTrayClickBehavior,
        WindowsTrayClickBehavior.showCompact);
    expect(defaults.windowsCompactAlwaysOnTop, isTrue);
    expect(defaults.windowsCompactPosition, isNull);

    await repository.save(
      defaults.copyWith(
        windowsCloseBehavior: WindowsCloseBehavior.showCompact,
        windowsTrayClickBehavior: WindowsTrayClickBehavior.openFull,
        windowsCompactAlwaysOnTop: false,
        windowsCompactPositionX: 240,
        windowsCompactPositionY: 128,
        windowsReminderPauseUntil: DateTime(2026, 7, 4, 18, 30),
      ),
    );

    final saved = await repository.load();
    expect(saved.windowsCloseBehavior, WindowsCloseBehavior.showCompact);
    expect(saved.windowsTrayClickBehavior, WindowsTrayClickBehavior.openFull);
    expect(saved.windowsCompactAlwaysOnTop, isFalse);
    expect(saved.windowsCompactPositionX, 240);
    expect(saved.windowsCompactPositionY, 128);
    expect(saved.windowsReminderPauseUntil, DateTime(2026, 7, 4, 18, 30));

    await repository.save(
      saved.copyWith(
        windowsCompactPositionX: null,
        windowsCompactPositionY: null,
        windowsReminderPauseUntil: null,
      ),
    );

    final reset = await repository.load();
    expect(reset.windowsCompactPosition, isNull);
    expect(reset.windowsReminderPauseUntil, isNull);
  });
}
