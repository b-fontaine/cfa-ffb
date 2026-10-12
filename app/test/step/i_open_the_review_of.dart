import 'package:flutter_test/flutter_test.dart';

/// Usage: I open the review of {'Hugo'}
Future<void> iOpenTheReviewOf(WidgetTester tester, String name) async {
  await tester.tap(find.text('Students'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  final review = find.text('Maturity review');
  await tester.ensureVisible(review);
  await tester.tap(review);
  await tester.pumpAndSettle();
}
