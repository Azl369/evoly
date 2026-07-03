import 'package:flutter/material.dart';

class EvolyDesignTokens extends ThemeExtension<EvolyDesignTokens> {
  const EvolyDesignTokens({
    required this.pageBackground,
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceRaised,
    required this.outlineSubtle,
    required this.shadowSoft,
    required this.priorityHigh,
    required this.priorityMedium,
    required this.priorityLow,
    required this.statusSuccess,
    required this.statusWarning,
    required this.statusInfo,
    required this.statusNeutral,
    required this.coachAccent,
    required this.chartPalette,
  });

  final Color pageBackground;
  final Color surface;
  final Color surfaceSubtle;
  final Color surfaceRaised;
  final Color outlineSubtle;
  final Color shadowSoft;
  final Color priorityHigh;
  final Color priorityMedium;
  final Color priorityLow;
  final Color statusSuccess;
  final Color statusWarning;
  final Color statusInfo;
  final Color statusNeutral;
  final Color coachAccent;
  final List<Color> chartPalette;

  static EvolyDesignTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<EvolyDesignTokens>() ??
        EvolyDesignTokens.from(theme.colorScheme);
  }

  static EvolyDesignTokens from(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final pageBackground = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: isDark ? 0.045 : 0.025),
      colorScheme.surface,
    );
    final surfaceSubtle = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: isDark ? 0.07 : 0.035),
      colorScheme.surfaceContainerLow,
    );
    final surfaceRaised = Color.alphaBlend(
      colorScheme.secondary.withValues(alpha: isDark ? 0.08 : 0.025),
      colorScheme.surfaceContainerLowest,
    );

    return EvolyDesignTokens(
      pageBackground: pageBackground,
      surface: colorScheme.surface,
      surfaceSubtle: surfaceSubtle,
      surfaceRaised: surfaceRaised,
      outlineSubtle: colorScheme.outlineVariant.withValues(
        alpha: isDark ? 0.38 : 0.68,
      ),
      shadowSoft: colorScheme.shadow.withValues(alpha: isDark ? 0.18 : 0.08),
      priorityHigh: colorScheme.error,
      priorityMedium: colorScheme.tertiary,
      priorityLow: colorScheme.primary,
      statusSuccess: colorScheme.tertiary,
      statusWarning: const Color(0xFFD97706),
      statusInfo: colorScheme.secondary,
      statusNeutral: colorScheme.onSurfaceVariant,
      coachAccent: colorScheme.tertiary,
      chartPalette: [
        colorScheme.primary,
        colorScheme.tertiary,
        colorScheme.secondary,
        const Color(0xFFD97706),
        const Color(0xFF7C3AED),
        const Color(0xFF0F766E),
        colorScheme.error,
      ],
    );
  }

  @override
  EvolyDesignTokens copyWith({
    Color? pageBackground,
    Color? surface,
    Color? surfaceSubtle,
    Color? surfaceRaised,
    Color? outlineSubtle,
    Color? shadowSoft,
    Color? priorityHigh,
    Color? priorityMedium,
    Color? priorityLow,
    Color? statusSuccess,
    Color? statusWarning,
    Color? statusInfo,
    Color? statusNeutral,
    Color? coachAccent,
    List<Color>? chartPalette,
  }) {
    return EvolyDesignTokens(
      pageBackground: pageBackground ?? this.pageBackground,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      outlineSubtle: outlineSubtle ?? this.outlineSubtle,
      shadowSoft: shadowSoft ?? this.shadowSoft,
      priorityHigh: priorityHigh ?? this.priorityHigh,
      priorityMedium: priorityMedium ?? this.priorityMedium,
      priorityLow: priorityLow ?? this.priorityLow,
      statusSuccess: statusSuccess ?? this.statusSuccess,
      statusWarning: statusWarning ?? this.statusWarning,
      statusInfo: statusInfo ?? this.statusInfo,
      statusNeutral: statusNeutral ?? this.statusNeutral,
      coachAccent: coachAccent ?? this.coachAccent,
      chartPalette: chartPalette ?? this.chartPalette,
    );
  }

  @override
  EvolyDesignTokens lerp(
    ThemeExtension<EvolyDesignTokens>? other,
    double t,
  ) {
    if (other is! EvolyDesignTokens) {
      return this;
    }

    return EvolyDesignTokens(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      outlineSubtle: Color.lerp(outlineSubtle, other.outlineSubtle, t)!,
      shadowSoft: Color.lerp(shadowSoft, other.shadowSoft, t)!,
      priorityHigh: Color.lerp(priorityHigh, other.priorityHigh, t)!,
      priorityMedium: Color.lerp(priorityMedium, other.priorityMedium, t)!,
      priorityLow: Color.lerp(priorityLow, other.priorityLow, t)!,
      statusSuccess: Color.lerp(statusSuccess, other.statusSuccess, t)!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
      statusInfo: Color.lerp(statusInfo, other.statusInfo, t)!,
      statusNeutral: Color.lerp(statusNeutral, other.statusNeutral, t)!,
      coachAccent: Color.lerp(coachAccent, other.coachAccent, t)!,
      chartPalette: _lerpPalette(chartPalette, other.chartPalette, t),
    );
  }

  static List<Color> _lerpPalette(
    List<Color> a,
    List<Color> b,
    double t,
  ) {
    final length = a.length > b.length ? a.length : b.length;
    return [
      for (var index = 0; index < length; index += 1)
        Color.lerp(
          a[_clampedIndex(index, a.length)],
          b[_clampedIndex(index, b.length)],
          t,
        )!,
    ];
  }

  static int _clampedIndex(int index, int length) {
    return index.clamp(0, length - 1).toInt();
  }
}
