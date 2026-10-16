import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: nothing overflows the screen
///
/// Aucune erreur de débordement et pas de défilement horizontal : la barre
/// basse tient dans la largeur.
Future<void> nothingOverflowsTheScreen(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  final bar = tester.getRect(
    find.byKey(const ValueKey('presentation-bottom-bar')),
  );
  expect(bar.left, greaterThanOrEqualTo(0));
  expect(bar.right, lessThanOrEqualTo(screen.width + 0.5));
}
