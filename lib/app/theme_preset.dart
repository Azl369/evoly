import 'package:flutter/material.dart';

enum EvolyThemePreset {
  orbitBlue,
  forestGreen,
  sunriseCoral,
  graphiteFocus,
}

extension EvolyThemePresetInfo on EvolyThemePreset {
  String get id {
    return switch (this) {
      EvolyThemePreset.orbitBlue => 'orbitBlue',
      EvolyThemePreset.forestGreen => 'forestGreen',
      EvolyThemePreset.sunriseCoral => 'sunriseCoral',
      EvolyThemePreset.graphiteFocus => 'graphiteFocus',
    };
  }

  String get label {
    return switch (this) {
      EvolyThemePreset.orbitBlue => '星轨蓝',
      EvolyThemePreset.forestGreen => '极光绿',
      EvolyThemePreset.sunriseCoral => '暮光橙',
      EvolyThemePreset.graphiteFocus => '石墨 HUD',
    };
  }

  Color get seedColor {
    return switch (this) {
      EvolyThemePreset.orbitBlue => const Color(0xFF6EA8FF),
      EvolyThemePreset.forestGreen => const Color(0xFF37C98B),
      EvolyThemePreset.sunriseCoral => const Color(0xFFFF8A5B),
      EvolyThemePreset.graphiteFocus => const Color(0xFF8AA0B8),
    };
  }

  Color get secondarySeedColor {
    return switch (this) {
      EvolyThemePreset.orbitBlue => const Color(0xFF28D8C0),
      EvolyThemePreset.forestGreen => const Color(0xFF66D9E8),
      EvolyThemePreset.sunriseCoral => const Color(0xFF35C2A6),
      EvolyThemePreset.graphiteFocus => const Color(0xFF5EEAD4),
    };
  }

  Color get tertiarySeedColor {
    return switch (this) {
      EvolyThemePreset.orbitBlue => const Color(0xFF9C7CFF),
      EvolyThemePreset.forestGreen => const Color(0xFFE5B454),
      EvolyThemePreset.sunriseCoral => const Color(0xFF7DA8FF),
      EvolyThemePreset.graphiteFocus => const Color(0xFFC084FC),
    };
  }

  List<Color> get previewSwatches {
    return [
      seedColor,
      secondarySeedColor,
      tertiarySeedColor,
    ];
  }
}

EvolyThemePreset evolyThemePresetFromId(String? id) {
  for (final preset in EvolyThemePreset.values) {
    if (preset.id == id) {
      return preset;
    }
  }

  return EvolyThemePreset.orbitBlue;
}
