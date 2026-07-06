import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evoly/app/theme.dart';
import 'package:evoly/shared/ui/components/app_components.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';

void main() {
  testWidgets('AppSurface maps variants to semantic surface tokens', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      const AppSurface(child: Text('Raised surface')),
    );

    var tokens = EvolyDesignTokens.of(tester.element(find.byType(AppSurface)));
    var decoration = _surfaceDecoration(tester);
    var border = decoration.border! as Border;

    expect(decoration.color, tokens.cardSurface);
    expect(decoration.boxShadow, same(tokens.shadowLow));
    expect(border.top.color, tokens.borderSubtle);

    await _pumpComponent(
      tester,
      const AppSurface(
        variant: AppSurfaceVariant.selected,
        child: Text('Selected surface'),
      ),
    );

    tokens = EvolyDesignTokens.of(tester.element(find.byType(AppSurface)));
    decoration = _surfaceDecoration(tester);
    border = decoration.border! as Border;

    expect(decoration.boxShadow, same(tokens.shadowMedium));
    expect(border.top.color, tokens.borderEmphasized);
  });

  testWidgets('AppSurface handles tap interactions', (tester) async {
    var tapped = false;

    await _pumpComponent(
      tester,
      AppSurface(
        onTap: () => tapped = true,
        child: const Text('Tap surface'),
      ),
    );

    await tester.tap(find.text('Tap surface'));

    expect(tapped, isTrue);
  });

  testWidgets('AppSection renders header metadata and content', (tester) async {
    await _pumpComponent(
      tester,
      const AppSection(
        title: 'Today',
        subtitle: 'Next actions',
        trailing: Icon(Icons.add),
        child: Text('Section body'),
      ),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Next actions'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Section body'), findsOneWidget);
  });

  testWidgets('AppField renders label, required mark, and error text', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      const AppField(
        label: 'Task name',
        helperText: 'Shown when valid',
        errorText: 'Required',
        isRequired: true,
        child: TextField(),
      ),
    );

    final theme = AppTheme.light();
    final error = tester.widget<Text>(find.text('Required'));
    final mark = tester.widget<Text>(find.text(' *'));

    expect(find.text('Task name'), findsOneWidget);
    expect(find.text('Shown when valid'), findsNothing);
    expect(error.style?.color, theme.colorScheme.error);
    expect(mark.style?.color, theme.colorScheme.error);
  });

  testWidgets('AppStatusBadge renders label and icon', (tester) async {
    await _pumpComponent(
      tester,
      const AppStatusBadge(
        label: 'Synced',
        color: Colors.green,
        icon: Icons.check,
        compact: false,
      ),
    );

    expect(find.text('Synced'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}

Future<void> _pumpComponent(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(child: child),
      ),
    ),
  );
}

BoxDecoration _surfaceDecoration(WidgetTester tester) {
  final decoratedBox = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(AppSurface),
      matching: find.byType(DecoratedBox),
    ),
  );
  return decoratedBox.decoration as BoxDecoration;
}
