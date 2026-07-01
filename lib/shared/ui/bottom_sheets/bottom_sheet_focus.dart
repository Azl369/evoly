import 'package:flutter/widgets.dart';
import 'package:evoly/shared/ui/motion/motion_tokens.dart';

const bottomSheetKeyboardFocusDelay = MotionTokens.normal;

Future<void> requestFocusAfterBottomSheetEntrance(
  State state,
  FocusNode focusNode,
) async {
  await Future<void>.delayed(bottomSheetKeyboardFocusDelay);
  if (!state.mounted) {
    return;
  }

  focusNode.requestFocus();
}
