import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evoly/app/theme.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/shared/ui/components/slide_select_field.dart';

void main() {
  testWidgets('long press drag selects value with floating options', (
    tester,
  ) async {
    var selected = Priority.medium;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return SlideSelectField<Priority>(
                    label: '优先级',
                    values: const [
                      Priority.high,
                      Priority.medium,
                      Priority.low,
                    ],
                    value: selected,
                    labelBuilder: (priority) => priority.label,
                    icon: Icons.flag_rounded,
                    colorBuilder: (context, priority) {
                      final colors = Theme.of(context).colorScheme;
                      return switch (priority) {
                        Priority.high => colors.error,
                        Priority.medium => colors.tertiary,
                        Priority.low => colors.primary,
                      };
                    },
                    onChanged: (value) {
                      setState(() => selected = value);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('中'), findsOneWidget);
    expect(find.text('低'), findsNothing);

    final field = find.byType(SlideSelectField<Priority>);
    final gesture = await tester.startGesture(tester.getCenter(field));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 80));

    expect(find.text('低'), findsOneWidget);

    await gesture.moveBy(const Offset(0, 45));
    await tester.pump();

    expect(selected, Priority.low);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('低'), findsOneWidget);
    expect(find.text('高'), findsNothing);
  });
}
