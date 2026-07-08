import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evoly/app/theme.dart';
import 'package:evoly/shared/ui/bottom_sheets/adaptive_form_modal.dart';
import 'package:evoly/shared/ui/bottom_sheets/bottom_sheet_focus.dart';
import 'package:evoly/shared/ui/bottom_sheets/bottom_sheet_form_layout.dart';
import 'package:evoly/shared/ui/bottom_sheets/responsive_bottom_sheet_body.dart';

void main() {
  testWidgets('BottomSheetFormLayout renders header, content, and footer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: BottomSheetFormLayout(
            title: 'Edit item',
            subtitle: 'Autosaves as you type',
            trailing: Icon(Icons.sync),
            footer: Text('Done action'),
            children: [
              Text('Name field'),
              Text('Reminder field'),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(ResponsiveBottomSheetBody), findsOneWidget);
    expect(find.text('Edit item'), findsOneWidget);
    expect(find.text('Autosaves as you type'), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsOneWidget);
    expect(find.text('Name field'), findsOneWidget);
    expect(find.text('Reminder field'), findsOneWidget);
    expect(find.text('Done action'), findsOneWidget);
  });

  testWidgets(
      'ResponsiveBottomSheetBody avoids keyboard inset without animated layers',
      (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(390, 720),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: Scaffold(
            body: ResponsiveBottomSheetBody(
              child: Text('Keyboard aware content'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AnimatedPadding), findsNothing);
    expect(find.byType(AnimatedContainer), findsNothing);
    expect(
      find.byKey(const ValueKey('bottom-sheet-keyboard-transform')),
      findsNothing,
    );
    expect(find.text('Keyboard aware content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('keyboard focus is immediate on Android form route', () {
    expect(
      bottomSheetKeyboardFocusDelay,
      lessThan(const Duration(milliseconds: 180)),
    );
    expect(androidFormKeyboardFocusDelay, Duration.zero);
  });

  testWidgets('ResponsiveBottomSheetBody avoids overflow on compact keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 520),
            padding: EdgeInsets.only(top: 24),
            viewInsets: EdgeInsets.only(bottom: 320),
          ),
          child: Scaffold(
            body: ResponsiveBottomSheetBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  8,
                  (index) => SizedBox(
                    height: 56,
                    child: Text('Field $index'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Field 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ResponsiveBottomSheetBody becomes page content in full-screen mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const EvolyFormPresentationScope(
          presentation: EvolyFormPresentation.fullScreen,
          child: ResponsiveBottomSheetBody(
            child: Text('Legacy form content'),
          ),
        ),
      ),
    );

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.resizeToAvoidBottomInset, isFalse);
    expect(find.text('Legacy form content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BottomSheetFormLayout uses page layout in full-screen mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const EvolyFormPresentationScope(
          presentation: EvolyFormPresentation.fullScreen,
          child: BottomSheetFormLayout(
            title: 'Create goal',
            footer: Text('Create action'),
            children: [Text('Goal field')],
          ),
        ),
      ),
    );

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(ResponsiveBottomSheetBody), findsNothing);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.resizeToAvoidBottomInset, isFalse);
    expect(find.text('Create goal'), findsOneWidget);
    expect(find.text('Create action'), findsOneWidget);
    expect(find.text('Goal field'), findsOneWidget);
  });

  testWidgets('adaptive form modal uses full-screen route on Android', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    showAdaptiveFormModal<void>(
                      context: context,
                      builder: (context) {
                        return const BottomSheetFormLayout(
                          title: 'Android form',
                          children: [Text('Android field')],
                        );
                      },
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Android form'), findsOneWidget);
      expect(find.text('Android field'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Text('Platform reset'),
          ),
        ),
      );
    }
  });
}
