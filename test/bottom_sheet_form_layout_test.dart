import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evoly/app/theme.dart';
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
}
