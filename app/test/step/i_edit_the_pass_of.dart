import 'package:flutter_test/flutter_test.dart';

/// Usage: I edit the pass {'6 of 9'} of {'Léa'}
///
/// Ouvre la correction du premier passage de l'élève portant ce score.
Future<void> iEditThePassOf(
  WidgetTester tester,
  String score,
  String name,
) async {
  final button = find.byTooltip('Edit the pass of $name ($score)').first;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
