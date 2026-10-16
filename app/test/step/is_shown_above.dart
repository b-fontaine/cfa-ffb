import 'package:flutter_test/flutter_test.dart';

/// Usage: {'Hugo'} is shown above {'Léa'}
Future<void> isShownAbove(
  WidgetTester tester,
  String upper,
  String lower,
) async {
  final first = find.text(upper);
  final second = find.text(lower);
  expect(first, findsOneWidget);
  expect(second, findsOneWidget);
  expect(
    tester.getTopLeft(first).dy,
    lessThan(tester.getTopLeft(second).dy),
    reason: '$upper doit être affiché au-dessus de $lower',
  );
}
