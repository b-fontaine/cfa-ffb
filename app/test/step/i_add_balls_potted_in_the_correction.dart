import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I add {1} balls potted in the correction
///
/// Compteur de la boîte « Modifier le passage » (distinct de celui de la
/// carte de saisie, qui reste derrière la boîte).
Future<void> iAddBallsPottedInTheCorrection(
  WidgetTester tester,
  num count,
) async {
  final button = find.descendant(
    of: find.byType(Dialog),
    matching: find.byTooltip('More balls potted in the correction'),
  );
  for (var i = 0; i < count; i++) {
    await tester.tap(button);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
