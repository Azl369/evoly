import 'package:flutter/animation.dart';

class MotionTokens {
  static const instant = Duration(milliseconds: 80);
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 360);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
  static const Curve gentle = Curves.easeInOut;
}
