import 'package:flutter_test/flutter_test.dart';

/// Usage: I add {3} attempts for {'Léa'}
Future<void> iAddAttemptsFor(
  WidgetTester tester,
  num count,
  String name,
) async {
  final button = find.byTooltip('More attempts for $name');
  for (var i = 0; i < count; i++) {
    await tester.tap(button);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
