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
      EvolyThemePreset.orbitBlue => '默认蓝',
      EvolyThemePreset.forestGreen => '森林绿',
      EvolyThemePreset.sunriseCoral => '日出暖橙',
      EvolyThemePreset.graphiteFocus => '墨灰',
    };
  }

  Color get seedColor {
    return switch (this) {
      EvolyThemePreset.orbitBlue => const Color(0xFF5B6CFF),
      EvolyThemePreset.forestGreen => const Color(0xFF2F7D5B),
      EvolyThemePreset.sunriseCoral => const Color(0xFFE66A4E),
      EvolyThemePreset.graphiteFocus => const Color(0xFF5F6F7A),
    };
  }

  Color get secondarySeedColor {
    return switch (this) {
      EvolyThemePreset.orbitBlue => const Color(0xFF1F9BB4),
      EvolyThemePreset.forestGreen => const Color(0xFF4C8C4A),
      EvolyThemePreset.sunriseCoral => const Color(0xFFD08C2E),
      EvolyThemePreset.graphiteFocus => const Color(0xFF6D7C5F),
    };
  }

  Color get tertiarySeedColor {
    return switch (this) {
      EvolyThemePreset.orbitBlue => const Color(0xFF7C5CFF),
      EvolyThemePreset.forestGreen => const Color(0xFFC58F2A),
      EvolyThemePreset.sunriseCoral => const Color(0xFF4F8D7A),
      EvolyThemePreset.graphiteFocus => const Color(0xFF9A6A58),
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
