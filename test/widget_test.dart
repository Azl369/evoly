import 'package:flutter_test/flutter_test.dart';
import 'package:evoly/app/app.dart';

void main() {
  testWidgets('renders today shell', (tester) async {
    await tester.pumpWidget(const EvolyApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('今日计划'), findsOneWidget);
  });
}
