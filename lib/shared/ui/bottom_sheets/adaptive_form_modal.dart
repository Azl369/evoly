import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum EvolyFormPresentation {
  bottomSheet,
  fullScreen,
}

class EvolyFormPresentationScope extends InheritedWidget {
  const EvolyFormPresentationScope({
    required this.presentation,
    required super.child,
    super.key,
  });

  final EvolyFormPresentation presentation;

  static EvolyFormPresentation of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<EvolyFormPresentationScope>();
    return scope?.presentation ?? EvolyFormPresentation.bottomSheet;
  }

  @override
  bool updateShouldNotify(EvolyFormPresentationScope oldWidget) {
    return presentation != oldWidget.presentation;
  }
}

Future<T?> showAdaptiveFormModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool showDragHandle = true,
  bool isScrollControlled = true,
  bool? requestFocus,
  bool useSafeArea = false,
  AnimationStyle? sheetAnimationStyle,
}) {
  if (_usesFullScreenFormRoute) {
    return Navigator.of(context).push<T>(
      _AndroidFormPageRoute<T>(builder: builder),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    requestFocus: requestFocus,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    sheetAnimationStyle: sheetAnimationStyle,
    builder: (context) {
      return EvolyFormPresentationScope(
        presentation: EvolyFormPresentation.bottomSheet,
        child: Builder(builder: builder),
      );
    },
  );
}

bool get _usesFullScreenFormRoute {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

class _AndroidFormPageRoute<T> extends PageRouteBuilder<T> {
  _AndroidFormPageRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) {
            return EvolyFormPresentationScope(
              presentation: EvolyFormPresentation.fullScreen,
              child: Builder(builder: builder),
            );
          },
        );

  @override
  bool didPop(T? result) {
    FocusManager.instance.primaryFocus?.unfocus();
    return super.didPop(result);
  }
}
