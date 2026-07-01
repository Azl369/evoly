import 'package:flutter/material.dart';
import 'package:evoly/shared/ui/tokens/app_radii.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';

class AppTheme {
  static const _fontFamilyFallback = [
    'MiSans',
    'HarmonyOS Sans SC',
    'OPPO Sans',
    'vivo Sans',
    'Roboto',
    'Segoe UI Variable',
    'Segoe UI',
    'PingFang SC',
    'Microsoft YaHei UI',
    'Noto Sans CJK SC',
    'Noto Sans SC',
    'Arial',
    'sans-serif',
  ];

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B6CFF),
      brightness: Brightness.light,
    );

    return _base(colorScheme);
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8EA0FF),
      brightness: Brightness.dark,
    );

    return _base(colorScheme);
  }

  static ThemeData _base(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamilyFallback: _fontFamilyFallback,
      textTheme: _textTheme(colorScheme),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        titleTextStyle: _textStyle(
          color: colorScheme.onSurface,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          height: 1.22,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return _textStyle(
            color: states.contains(WidgetState.selected)
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            height: 1.16,
          );
        }),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme colorScheme) {
    return TextTheme(
      displayLarge: _textStyle(
        color: colorScheme.onSurface,
        fontSize: 36,
        fontWeight: FontWeight.w600,
        height: 1.14,
        letterSpacing: -0.2,
      ),
      displayMedium: _textStyle(
        color: colorScheme.onSurface,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.15,
        letterSpacing: -0.15,
      ),
      displaySmall: _textStyle(
        color: colorScheme.onSurface,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.18,
        letterSpacing: -0.1,
      ),
      headlineLarge: _textStyle(
        color: colorScheme.onSurface,
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      headlineMedium: _textStyle(
        color: colorScheme.onSurface,
        fontSize: 23,
        fontWeight: FontWeight.w600,
        height: 1.22,
      ),
      headlineSmall: _textStyle(
        color: colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.26,
      ),
      titleLarge: _textStyle(
        color: colorScheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.28,
      ),
      titleMedium: _textStyle(
        color: colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleSmall: _textStyle(
        color: colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.28,
      ),
      bodyLarge: _textStyle(
        color: colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.44,
      ),
      bodyMedium: _textStyle(
        color: colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.42,
      ),
      bodySmall: _textStyle(
        color: colorScheme.onSurfaceVariant,
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        height: 1.34,
      ),
      labelLarge: _textStyle(
        color: colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      labelMedium: _textStyle(
        color: colorScheme.onSurfaceVariant,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        height: 1.18,
        letterSpacing: 0.05,
      ),
      labelSmall: _textStyle(
        color: colorScheme.onSurfaceVariant,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        height: 1.16,
        letterSpacing: 0.05,
      ),
    );
  }

  static TextStyle _textStyle({
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamilyFallback: _fontFamilyFallback,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
