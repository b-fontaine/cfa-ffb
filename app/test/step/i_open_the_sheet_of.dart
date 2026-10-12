import 'package:flutter_test/flutter_test.dart';

/// Usage: I open the sheet of {'Léa'}
Future<void> iOpenTheSheetOf(WidgetTester tester, String name) async {
  await tester.tap(find.text('Students'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}
