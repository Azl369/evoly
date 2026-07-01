import 'package:flutter/material.dart';
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
    final maxHeight = (mediaQuery.size.height -
            mediaQuery.viewInsets.bottom -
            mediaQuery.padding.top -
            AppSpacing.lg)
        .clamp(minHeight, mediaQuery.size.height);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          mediaQuery.viewInsets.bottom + AppSpacing.md,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: RepaintBoundary(child: child),
          ),
        ),
      ),
    );
  }
}
