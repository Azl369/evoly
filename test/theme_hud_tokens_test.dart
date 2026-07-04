import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evoly/app/theme.dart';
import 'package:evoly/app/theme_preset.dart';
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

  test('copies and lerps new HUD token fields', () {
    final tokens = AppTheme.light().extension<EvolyDesignTokens>()!.copyWith(
          glassBlurSigma: 30,
          hudAccent: Colors.red,
          backgroundGradient: const LinearGradient(
            colors: [Colors.red, Colors.blue],
          ),
        );
    final other = tokens.copyWith(
      glassBlurSigma: 10,
      hudAccent: Colors.blue,
      backgroundGradient: const LinearGradient(
        colors: [Colors.blue, Colors.green],
      ),
    );
    final lerped = tokens.lerp(other, 0.5);

    expect(tokens.glassBlurSigma, 30);
    expect(tokens.hudAccent, Colors.red);
    expect(lerped.glassBlurSigma, 20);
    expect(lerped.hudAccent, Color.lerp(Colors.red, Colors.blue, 0.5));
    expect(lerped.backgroundGradient, isA<LinearGradient>());
  });
}
