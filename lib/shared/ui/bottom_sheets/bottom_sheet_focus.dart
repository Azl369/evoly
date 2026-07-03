import 'package:flutter/widgets.dart';

const bottomSheetKeyboardFocusDelay = Duration(milliseconds: 420);

Future<void> requestFocusAfterBottomSheetEntrance(
  State state,
  FocusNode focusNode,
) async {
  await Future<void>.delayed(bottomSheetKeyboardFocusDelay);
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
