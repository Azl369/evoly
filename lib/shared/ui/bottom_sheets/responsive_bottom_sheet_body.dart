import 'package:flutter/material.dart';
import 'package:evoly/shared/ui/bottom_sheets/adaptive_form_modal.dart';
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
    if (EvolyFormPresentationScope.of(context) ==
        EvolyFormPresentation.fullScreen) {
      return _ResponsiveFullScreenBody(child: child);
    }

    final mediaQuery = MediaQuery.of(context);
    final horizontalInset =
        mediaQuery.size.width >= 720 ? AppSpacing.xl : AppSpacing.pageGutter;
    final availableHeight = mediaQuery.size.height -
        mediaQuery.viewInsets.bottom -
        mediaQuery.padding.top -
        mediaQuery.padding.bottom -
        AppSpacing.lg;
    final maxHeight =
        availableHeight.clamp(minHeight, mediaQuery.size.height).toDouble();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalInset,
          0,
          horizontalInset,
          mediaQuery.viewInsets.bottom + AppSpacing.md,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
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

class _ResponsiveFullScreenBody extends StatelessWidget {
  const _ResponsiveFullScreenBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.xs,
                  right: AppSpacing.sm,
                ),
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
