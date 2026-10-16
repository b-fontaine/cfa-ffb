import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the buttons are at least {48} dp high
///
/// Chaque bouton affiché mesure au moins [height] dp de haut (cible tactile).
Future<void> theButtonsAreAtLeastDpHigh(WidgetTester tester, num height) async {
  final buttons = find.byWidgetPredicate((w) => w is ButtonStyleButton);
  expect(buttons, findsWidgets);
  for (final element in buttons.evaluate()) {
    final size = tester.getSize(find.byElementPredicate((e) => e == element));
    expect(
      size.height,
      greaterThanOrEqualTo(height),
      reason: 'bouton trop bas : $size',
    );
  }
}
