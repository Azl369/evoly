import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class EvolyDesignTokens extends ThemeExtension<EvolyDesignTokens> {
  const EvolyDesignTokens({
    required this.pageBackground,
    required this.backgroundGradient,
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceRaised,
    required this.glassSurface,
    required this.glassSurfaceSubtle,
    required this.glassSurfaceRaised,
    required this.glassBorder,
    required this.glassBorderStrong,
    required this.glassHighlight,
    required this.outlineSubtle,
    required this.shadowSoft,
    required this.glassShadow,
    required this.hudAccent,
    required this.hudAccentStrong,
    required this.metricAccent,
    required this.priorityHigh,
    required this.priorityMedium,
    required this.priorityLow,
    required this.statusSuccess,
    required this.statusWarning,
    required this.statusInfo,
    required this.statusNeutral,
    required this.coachAccent,
    required this.chartPalette,
    required this.glassBlurSigma,
  });

  final Color pageBackground;
  final Gradient backgroundGradient;
  final Color surface;
  final Color surfaceSubtle;
  final Color surfaceRaised;
  final Color glassSurface;
  final Color glassSurfaceSubtle;
  final Color glassSurfaceRaised;
  final Color glassBorder;
  final Color glassBorderStrong;
  final Color glassHighlight;
  final Color outlineSubtle;
  final Color shadowSoft;
  final Color glassShadow;
  final Color hudAccent;
  final Color hudAccentStrong;
  final Color metricAccent;
  final Color priorityHigh;
  final Color priorityMedium;
  final Color priorityLow;
  final Color statusSuccess;
  final Color statusWarning;
  final Color statusInfo;
  final Color statusNeutral;
  final Color coachAccent;
  final List<Color> chartPalette;
  final double glassBlurSigma;

  static EvolyDesignTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<EvolyDesignTokens>() ??
        EvolyDesignTokens.from(theme.colorScheme);
  }

  static EvolyDesignTokens from(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final pageBackground = isDark
        ? Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.08),
            const Color(0xFF0B111B),
          )
        : Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.045),
            const Color(0xFFF5FAFF),
          );
    final backgroundGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              pageBackground,
              Color.alphaBlend(
                colorScheme.secondary.withValues(alpha: 0.08),
                const Color(0xFF0D1A21),
              ),
              Color.alphaBlend(
                colorScheme.tertiary.withValues(alpha: 0.08),
                const Color(0xFF171323),
              ),
            ]
          : [
              pageBackground,
              Color.alphaBlend(
                colorScheme.secondary.withValues(alpha: 0.065),
                const Color(0xFFF4FFFC),
              ),
              Color.alphaBlend(
                colorScheme.tertiary.withValues(alpha: 0.055),
                const Color(0xFFFBF8FF),
              ),
            ],
    );
    final glassSurface =
        isDark ? const Color(0xC01A2636) : const Color(0xDFFFFFFF);
    final glassSurfaceSubtle =
        isDark ? const Color(0x94223042) : const Color(0xBFFFFFFF);
    final glassSurfaceRaised =
        isDark ? const Color(0xCC26364B) : const Color(0xEAFFFFFF);
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.13)
        : Colors.white.withValues(alpha: 0.66);
    final glassBorderStrong = isDark
        ? colorScheme.primary.withValues(alpha: 0.44)
        : colorScheme.primary.withValues(alpha: 0.30);
    final glassShadow = isDark
        ? Colors.black.withValues(alpha: 0.26)
        : const Color(0xFF284B63).withValues(alpha: 0.10);
    final outlineSubtle = isDark
        ? Colors.white.withValues(alpha: 0.11)
        : const Color(0xFF5E7A91).withValues(alpha: 0.18);

    return EvolyDesignTokens(
      pageBackground: pageBackground,
      backgroundGradient: backgroundGradient,
      surface: glassSurface,
      surfaceSubtle: glassSurfaceSubtle,
      surfaceRaised: glassSurfaceRaised,
      glassSurface: glassSurface,
      glassSurfaceSubtle: glassSurfaceSubtle,
      glassSurfaceRaised: glassSurfaceRaised,
      glassBorder: glassBorder,
      glassBorderStrong: glassBorderStrong,
      glassHighlight: Colors.white.withValues(alpha: isDark ? 0.16 : 0.72),
      outlineSubtle: outlineSubtle,
      shadowSoft: glassShadow,
      glassShadow: glassShadow,
      hudAccent: colorScheme.primary,
      hudAccentStrong: isDark ? colorScheme.primaryFixed : colorScheme.primary,
      metricAccent: colorScheme.secondary,
      priorityHigh: colorScheme.error,
      priorityMedium: colorScheme.tertiary,
      priorityLow: colorScheme.primary,
      statusSuccess: colorScheme.secondary,
      statusWarning: const Color(0xFFD97706),
      statusInfo: colorScheme.primary,
      statusNeutral: colorScheme.onSurfaceVariant,
      coachAccent: colorScheme.tertiary,
      chartPalette: [
        colorScheme.primary,
        colorScheme.secondary,
        colorScheme.tertiary,
        const Color(0xFFD97706),
        const Color(0xFF7C3AED),
        const Color(0xFF0F766E),
        colorScheme.error,
      ],
      glassBlurSigma: isDark ? 18 : 16,
    );
  }

  @override
  EvolyDesignTokens copyWith({
    Color? pageBackground,
    Gradient? backgroundGradient,
    Color? surface,
    Color? surfaceSubtle,
    Color? surfaceRaised,
    Color? glassSurface,
    Color? glassSurfaceSubtle,
    Color? glassSurfaceRaised,
    Color? glassBorder,
    Color? glassBorderStrong,
    Color? glassHighlight,
    Color? outlineSubtle,
    Color? shadowSoft,
    Color? glassShadow,
    Color? hudAccent,
    Color? hudAccentStrong,
    Color? metricAccent,
    Color? priorityHigh,
    Color? priorityMedium,
    Color? priorityLow,
    Color? statusSuccess,
    Color? statusWarning,
    Color? statusInfo,
    Color? statusNeutral,
    Color? coachAccent,
    List<Color>? chartPalette,
    double? glassBlurSigma,
  }) {
    return EvolyDesignTokens(
      pageBackground: pageBackground ?? this.pageBackground,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      glassSurface: glassSurface ?? this.glassSurface,
      glassSurfaceSubtle: glassSurfaceSubtle ?? this.glassSurfaceSubtle,
      glassSurfaceRaised: glassSurfaceRaised ?? this.glassSurfaceRaised,
      glassBorder: glassBorder ?? this.glassBorder,
      glassBorderStrong: glassBorderStrong ?? this.glassBorderStrong,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      outlineSubtle: outlineSubtle ?? this.outlineSubtle,
      shadowSoft: shadowSoft ?? this.shadowSoft,
      glassShadow: glassShadow ?? this.glassShadow,
      hudAccent: hudAccent ?? this.hudAccent,
      hudAccentStrong: hudAccentStrong ?? this.hudAccentStrong,
      metricAccent: metricAccent ?? this.metricAccent,
      priorityHigh: priorityHigh ?? this.priorityHigh,
      priorityMedium: priorityMedium ?? this.priorityMedium,
      priorityLow: priorityLow ?? this.priorityLow,
      statusSuccess: statusSuccess ?? this.statusSuccess,
      statusWarning: statusWarning ?? this.statusWarning,
      statusInfo: statusInfo ?? this.statusInfo,
      statusNeutral: statusNeutral ?? this.statusNeutral,
      coachAccent: coachAccent ?? this.coachAccent,
      chartPalette: chartPalette ?? this.chartPalette,
      glassBlurSigma: glassBlurSigma ?? this.glassBlurSigma,
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
      backgroundGradient:
          Gradient.lerp(backgroundGradient, other.backgroundGradient, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassSurfaceSubtle:
          Color.lerp(glassSurfaceSubtle, other.glassSurfaceSubtle, t)!,
      glassSurfaceRaised:
          Color.lerp(glassSurfaceRaised, other.glassSurfaceRaised, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassBorderStrong:
          Color.lerp(glassBorderStrong, other.glassBorderStrong, t)!,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t)!,
      outlineSubtle: Color.lerp(outlineSubtle, other.outlineSubtle, t)!,
      shadowSoft: Color.lerp(shadowSoft, other.shadowSoft, t)!,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t)!,
      hudAccent: Color.lerp(hudAccent, other.hudAccent, t)!,
      hudAccentStrong: Color.lerp(hudAccentStrong, other.hudAccentStrong, t)!,
      metricAccent: Color.lerp(metricAccent, other.metricAccent, t)!,
      priorityHigh: Color.lerp(priorityHigh, other.priorityHigh, t)!,
      priorityMedium: Color.lerp(priorityMedium, other.priorityMedium, t)!,
      priorityLow: Color.lerp(priorityLow, other.priorityLow, t)!,
      statusSuccess: Color.lerp(statusSuccess, other.statusSuccess, t)!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
      statusInfo: Color.lerp(statusInfo, other.statusInfo, t)!,
      statusNeutral: Color.lerp(statusNeutral, other.statusNeutral, t)!,
      coachAccent: Color.lerp(coachAccent, other.coachAccent, t)!,
      chartPalette: _lerpPalette(chartPalette, other.chartPalette, t),
      glassBlurSigma: ui.lerpDouble(glassBlurSigma, other.glassBlurSigma, t)!,
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
