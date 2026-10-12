import 'package:flutter_test/flutter_test.dart';

/// Usage: I add {7} balls potted for {'Léa'}
Future<void> iAddBallsPottedFor(
  WidgetTester tester,
  num count,
  String name,
) async {
  final button = find.byTooltip('More balls potted for $name');
  for (var i = 0; i < count; i++) {
    await tester.tap(button);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
