import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/theme.dart';
import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/features/settings/application/settings_controller.dart';
import 'package:evoly/features/settings/data/settings_repository.dart';
import 'package:evoly/features/settings/presentation/settings_page.dart';
import 'package:evoly/features/sync/application/supabase_auth_controller.dart';
import 'package:evoly/features/sync/data/sqlite_sync_state_repository.dart';

void main() {
  testWidgets('renders grouped settings layout and opens theme sheet',
      (tester) async {
    final settingsController = SettingsController(_FakeSettingsRepository());
    final authController = SupabaseAuthController(
      null,
      SqliteSyncStateRepository(AppDatabase.testing('unused-sync-state.db')),
      authCallbackUrl: 'evoly://auth',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsController>.value(
            value: settingsController,
          ),
          ChangeNotifierProvider<SupabaseAuthController>.value(
            value: authController,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsPage(showBottomNavigationBar: false),
        ),
      ),
    );

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('提醒'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('账号与同步'), findsOneWidget);
    expect(find.text('跟随系统 · 星轨蓝'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, '主题'));
    await tester.pumpAndSettle();

    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('主题风格'), findsOneWidget);
    expect(find.text('石墨 HUD'), findsOneWidget);
  });
}

class _FakeSettingsRepository implements SettingsRepository {
  AppSettings settings = AppSettings.defaultSettings;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async {
    this.settings = settings;
  }
}
