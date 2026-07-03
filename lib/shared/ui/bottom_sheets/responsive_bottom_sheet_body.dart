import 'package:flutter/material.dart';
import 'package:evoly/shared/ui/motion/motion_tokens.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';

class ResponsiveBottomSheetBody extends StatelessWidget {
  const ResponsiveBottomSheetBody({
    required this.child,
    this.minHeight = 280,
    super.key,
  });

  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final transitionDuration =
        reduceMotion ? Duration.zero : MotionTokens.normal;
    final horizontalInset =
        mediaQuery.size.width >= 720 ? AppSpacing.xl : AppSpacing.pageGutter;
    final maxHeight = (mediaQuery.size.height -
            mediaQuery.viewInsets.bottom -
            mediaQuery.padding.top -
            AppSpacing.lg)
        .clamp(minHeight, mediaQuery.size.height);

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: transitionDuration,
        curve: MotionTokens.gentle,
        padding: EdgeInsets.fromLTRB(
          horizontalInset,
          0,
          horizontalInset,
          mediaQuery.viewInsets.bottom + AppSpacing.md,
        ),
        child: Center(
          child: AnimatedContainer(
            duration: transitionDuration,
            curve: MotionTokens.gentle,
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              maxWidth: 640,
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: RepaintBoundary(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
