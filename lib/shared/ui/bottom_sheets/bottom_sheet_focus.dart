import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const bottomSheetKeyboardFocusDelay = Duration(milliseconds: 120);
const androidFormKeyboardFocusDelay = Duration.zero;

Future<void> requestFocusAfterBottomSheetEntrance(
  State state,
  FocusNode focusNode,
) async {
  final delay = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? androidFormKeyboardFocusDelay
      : bottomSheetKeyboardFocusDelay;

  await Future<void>.delayed(delay);
  if (!state.mounted) {
    return;
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!state.mounted || !focusNode.canRequestFocus) {
      return;
    }

    focusNode.requestFocus();
  });
}
