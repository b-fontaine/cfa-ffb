import 'package:flutter_test/flutter_test.dart';

/// Usage: I delete the pass {'7 of 9'} of {'Léa'}
///
/// Appuie sur la suppression du premier passage de l'élève portant ce score ;
/// la confirmation est laissée au scénario.
Future<void> iDeleteThePassOf(
  WidgetTester tester,
  String score,
  String name,
) async {
  final button = find.byTooltip('Delete the pass of $name ($score)').first;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
