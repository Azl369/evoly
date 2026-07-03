import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/app_dependencies.dart';
import 'package:evoly/app/router.dart';
import 'package:evoly/app/theme.dart';
import 'package:evoly/features/settings/application/settings_controller.dart';
import 'package:evoly/shared/ui/motion/motion_tokens.dart';

class EvolyApp extends StatelessWidget {
  const EvolyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppDependencies(
      child: Consumer<SettingsController>(
        builder: (context, settingsController, _) {
          final settings = settingsController.settings;

          return MaterialApp(
            title: 'Evoly',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(settings.themePreset),
            darkTheme: AppTheme.dark(settings.themePreset),
            themeMode: settings.themeMode,
            themeAnimationDuration: MotionTokens.instant,
            themeAnimationCurve: MotionTokens.gentle,
            initialRoute: AppRoutes.today,
            onGenerateRoute: AppRouter.onGenerateRoute,
            builder: (context, child) {
              final theme = Theme.of(context);
              final isDark = theme.brightness == Brightness.dark;

              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness:
                      isDark ? Brightness.light : Brightness.dark,
                  statusBarBrightness:
                      isDark ? Brightness.dark : Brightness.light,
                  systemNavigationBarColor: theme.colorScheme.surface,
                  systemNavigationBarIconBrightness:
                      isDark ? Brightness.light : Brightness.dark,
                  systemNavigationBarDividerColor: Colors.transparent,
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
