import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evoly/app/theme.dart';
import 'package:evoly/app/theme_preset.dart';
import 'package:evoly/shared/ui/tokens/app_radii.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';

void main() {
  test('keeps persisted theme preset ids while updating HUD labels', () {
    expect(EvolyThemePreset.orbitBlue.id, 'orbitBlue');
    expect(EvolyThemePreset.forestGreen.id, 'forestGreen');
    expect(EvolyThemePreset.sunriseCoral.id, 'sunriseCoral');
    expect(EvolyThemePreset.graphiteFocus.id, 'graphiteFocus');
    expect(evolyThemePresetFromId('orbitBlue'), EvolyThemePreset.orbitBlue);
    expect(evolyThemePresetFromId('unknown'), EvolyThemePreset.orbitBlue);

    expect(EvolyThemePreset.orbitBlue.label, '星轨蓝');
    expect(EvolyThemePreset.graphiteFocus.label, '石墨 HUD');
  });

  test('provides HUD glass tokens for light and dark themes', () {
    for (final preset in EvolyThemePreset.values) {
      final light = AppTheme.light(preset).extension<EvolyDesignTokens>()!;
      final dark = AppTheme.dark(preset).extension<EvolyDesignTokens>()!;

      expect(light.glassBlurSigma, greaterThan(0));
      expect(dark.glassBlurSigma, greaterThan(0));
      expect(light.glassSurface.a, greaterThan(0));
      expect(dark.glassSurface.a, greaterThan(0));
      expect(light.backgroundGradient, isA<LinearGradient>());
      expect(dark.backgroundGradient, isA<LinearGradient>());
      expect(light.hudAccent, AppTheme.light(preset).colorScheme.primary);
      expect(light.metricAccent, AppTheme.light(preset).colorScheme.secondary);
    }
  });

  test('provides semantic surface text border and shadow tokens', () {
    for (final preset in EvolyThemePreset.values) {
      for (final theme in [AppTheme.light(preset), AppTheme.dark(preset)]) {
        final tokens = theme.extension<EvolyDesignTokens>()!;
        final colorScheme = theme.colorScheme;

        expect(tokens.bodyBackground, tokens.pageBackground);
        expect(tokens.cardSurface, tokens.glassSurfaceRaised);
        expect(tokens.popoverSurface, tokens.glassSurfaceRaised);
        expect(tokens.surfaceMuted, tokens.glassSurfaceSubtle);
        expect(tokens.borderSubtle, tokens.outlineSubtle);
        expect(tokens.borderEmphasized, tokens.glassBorderStrong);
        expect(tokens.textPrimary, colorScheme.onSurface);
        expect(tokens.textSecondary, colorScheme.onSurfaceVariant);

        expect(tokens.shadowLow, isNotEmpty);
        expect(tokens.shadowMedium, isNotEmpty);
        expect(tokens.shadowHigh, isNotEmpty);
        expect(tokens.shadowLow.single.color.a, greaterThan(0));
        expect(tokens.shadowMedium.single.color.a, greaterThan(0));
        expect(tokens.shadowHigh.single.color.a, greaterThan(0));
        expect(
          tokens.shadowLow.single.blurRadius,
          lessThan(tokens.shadowMedium.single.blurRadius),
        );
        expect(
          tokens.shadowMedium.single.blurRadius,
          lessThan(tokens.shadowHigh.single.blurRadius),
        );
        expect(
          tokens.shadowLow.single.offset.dy,
          lessThan(tokens.shadowMedium.single.offset.dy),
        );
        expect(
          tokens.shadowMedium.single.offset.dy,
          lessThan(tokens.shadowHigh.single.offset.dy),
        );
      }
    }
  });

  test('copies and lerps new HUD token fields', () {
    final tokens = AppTheme.light().extension<EvolyDesignTokens>()!.copyWith(
          glassBlurSigma: 30,
          hudAccent: Colors.red,
          bodyBackground: Colors.black,
          cardSurface: Colors.white,
          popoverSurface: Colors.orange,
          surfaceMuted: Colors.yellow,
          borderSubtle: Colors.purple,
          borderEmphasized: Colors.cyan,
          textPrimary: Colors.green,
          textSecondary: Colors.teal,
          shadowLow: const [
            BoxShadow(
              color: Colors.red,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
          shadowMedium: const [
            BoxShadow(
              color: Colors.green,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
          shadowHigh: const [
            BoxShadow(
              color: Colors.blue,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
          backgroundGradient: const LinearGradient(
            colors: [Colors.red, Colors.blue],
          ),
        );
    final other = tokens.copyWith(
      glassBlurSigma: 10,
      hudAccent: Colors.blue,
      bodyBackground: Colors.white,
      cardSurface: Colors.black,
      popoverSurface: Colors.blue,
      surfaceMuted: Colors.green,
      borderSubtle: Colors.orange,
      borderEmphasized: Colors.pink,
      textPrimary: Colors.yellow,
      textSecondary: Colors.deepPurple,
      shadowLow: const [
        BoxShadow(
          color: Colors.blue,
          blurRadius: 12,
          offset: Offset(0, 6),
        ),
      ],
      shadowMedium: const [
        BoxShadow(
          color: Colors.yellow,
          blurRadius: 16,
          offset: Offset(0, 8),
        ),
      ],
      shadowHigh: const [
        BoxShadow(
          color: Colors.purple,
          blurRadius: 20,
          offset: Offset(0, 10),
        ),
      ],
      backgroundGradient: const LinearGradient(
        colors: [Colors.blue, Colors.green],
      ),
    );
    final lerped = tokens.lerp(other, 0.5);

    expect(tokens.glassBlurSigma, 30);
    expect(tokens.hudAccent, Colors.red);
    expect(tokens.bodyBackground, Colors.black);
    expect(tokens.cardSurface, Colors.white);
    expect(tokens.popoverSurface, Colors.orange);
    expect(tokens.surfaceMuted, Colors.yellow);
    expect(tokens.borderSubtle, Colors.purple);
    expect(tokens.borderEmphasized, Colors.cyan);
    expect(tokens.textPrimary, Colors.green);
    expect(tokens.textSecondary, Colors.teal);
    expect(tokens.shadowLow.single.blurRadius, 4);
    expect(tokens.shadowMedium.single.blurRadius, 8);
    expect(tokens.shadowHigh.single.blurRadius, 12);
    expect(lerped.glassBlurSigma, 20);
    expect(lerped.hudAccent, Color.lerp(Colors.red, Colors.blue, 0.5));
    expect(
      lerped.bodyBackground,
      Color.lerp(Colors.black, Colors.white, 0.5),
    );
    expect(lerped.cardSurface, Color.lerp(Colors.white, Colors.black, 0.5));
    expect(lerped.popoverSurface, Color.lerp(Colors.orange, Colors.blue, 0.5));
    expect(lerped.surfaceMuted, Color.lerp(Colors.yellow, Colors.green, 0.5));
    expect(lerped.borderSubtle, Color.lerp(Colors.purple, Colors.orange, 0.5));
    expect(lerped.borderEmphasized, Color.lerp(Colors.cyan, Colors.pink, 0.5));
    expect(lerped.textPrimary, Color.lerp(Colors.green, Colors.yellow, 0.5));
    expect(
      lerped.textSecondary,
      Color.lerp(Colors.teal, Colors.deepPurple, 0.5),
    );
    expect(lerped.shadowLow.single.color,
        Color.lerp(Colors.red, Colors.blue, 0.5));
    expect(lerped.shadowLow.single.blurRadius, 8);
    expect(lerped.shadowLow.single.offset.dy, 4);
    expect(
      lerped.shadowMedium.single.color,
      Color.lerp(Colors.green, Colors.yellow, 0.5),
    );
    expect(lerped.shadowMedium.single.blurRadius, 12);
    expect(lerped.shadowMedium.single.offset.dy, 6);
    expect(
      lerped.shadowHigh.single.color,
      Color.lerp(Colors.blue, Colors.purple, 0.5),
    );
    expect(lerped.shadowHigh.single.blurRadius, 16);
    expect(lerped.shadowHigh.single.offset.dy, 8);
    expect(lerped.backgroundGradient, isA<LinearGradient>());
  });

  test('provides semantic radius aliases', () {
    expect(AppRadii.inner, 8);
    expect(AppRadii.element, 12);
    expect(AppRadii.container, 12);
    expect(AppRadii.page, 28);
  });
}
