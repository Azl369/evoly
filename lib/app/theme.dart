import 'package:flutter/material.dart';
import 'package:evoly/app/theme_preset.dart';
import 'package:evoly/shared/ui/tokens/app_radii.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';

class AppTheme {
  static final _lightThemeCache = <EvolyThemePreset, ThemeData>{};
  static final _darkThemeCache = <EvolyThemePreset, ThemeData>{};

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

  static ThemeData light([
    EvolyThemePreset preset = EvolyThemePreset.orbitBlue,
  ]) {
    return _lightThemeCache.putIfAbsent(
      preset,
      () => _base(_colorSchemeFor(preset, Brightness.light)),
    );
  }

  static ThemeData dark([
    EvolyThemePreset preset = EvolyThemePreset.orbitBlue,
  ]) {
    return _darkThemeCache.putIfAbsent(
      preset,
      () => _base(_colorSchemeFor(preset, Brightness.dark)),
    );
  }

  static ColorScheme _colorSchemeFor(
    EvolyThemePreset preset,
    Brightness brightness,
  ) {
    final base = ColorScheme.fromSeed(
      seedColor: preset.seedColor,
      brightness: brightness,
    );
    final secondary = ColorScheme.fromSeed(
      seedColor: preset.secondarySeedColor,
      brightness: brightness,
    );
    final tertiary = ColorScheme.fromSeed(
      seedColor: preset.tertiarySeedColor,
      brightness: brightness,
    );

    return base.copyWith(
      secondary: secondary.primary,
      onSecondary: secondary.onPrimary,
      secondaryContainer: secondary.primaryContainer,
      onSecondaryContainer: secondary.onPrimaryContainer,
      tertiary: tertiary.primary,
      onTertiary: tertiary.onPrimary,
      tertiaryContainer: tertiary.primaryContainer,
      onTertiaryContainer: tertiary.onPrimaryContainer,
    );
  }

  static ThemeData _base(ColorScheme colorScheme) {
    final tokens = EvolyDesignTokens.from(colorScheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: [tokens],
      fontFamilyFallback: _fontFamilyFallback,
      textTheme: _textTheme(colorScheme),
      scaffoldBackgroundColor: tokens.pageBackground,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: tokens.pageBackground,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
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
        color: tokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: tokens.outlineSubtle),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.compact,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: tokens.outlineSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.error, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: _textStyle(
            color: colorScheme.onPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.18,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          side: BorderSide(color: tokens.outlineSubtle),
          textStyle: _textStyle(
            color: colorScheme.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.18,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          textStyle: _textStyle(
            color: colorScheme.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.18,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSpacing.minTouchTarget),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(
            const Size(48, AppSpacing.minTouchTarget),
          ),
          side: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return BorderSide(
              color: selected ? colorScheme.primary : tokens.outlineSubtle,
            );
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: _textStyle(
          color: colorScheme.onInverseSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.28,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface.withValues(alpha: 0.98),
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.72),
        height: 68,
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
      ),
      displayMedium: _textStyle(
        color: colorScheme.onSurface,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.15,
      ),
      displaySmall: _textStyle(
        color: colorScheme.onSurface,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.18,
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
      ),
      labelSmall: _textStyle(
        color: colorScheme.onSurfaceVariant,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        height: 1.16,
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
