import 'package:flutter_test/flutter_test.dart';

/// Usage: I remove {3} attempts for {'Léa'}
Future<void> iRemoveAttemptsFor(
  WidgetTester tester,
  num count,
  String name,
) async {
  final button = find.byTooltip('Fewer attempts for $name');
  for (var i = 0; i < count; i++) {
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
