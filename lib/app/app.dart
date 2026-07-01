import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:evoly/app/app_dependencies.dart';
import 'package:evoly/app/router.dart';
import 'package:evoly/app/theme.dart';

class EvolyApp extends StatelessWidget {
  const EvolyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppDependencies(
      child: MaterialApp(
        title: 'Evoly',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
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
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: theme.colorScheme.surface,
              systemNavigationBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
              systemNavigationBarDividerColor: Colors.transparent,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
