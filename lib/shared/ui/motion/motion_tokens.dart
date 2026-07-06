import 'package:flutter/animation.dart';

class MotionTokens {
  /// Micro transitions such as theme swaps and immediate route feedback.
  static const instant = Duration(milliseconds: 80);

  /// Fast component feedback such as hover, press, and small state changes.
  static const fast = Duration(milliseconds: 150);

  /// Standard content and layout transitions.
  static const normal = Duration(milliseconds: 240);

  /// Expressive panel and HUD transitions that need more breathing room.
  static const slow = Duration(milliseconds: 360);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
  static const Curve gentle = Curves.easeInOut;
}
