import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the stage needs no scrolling
///
/// La zone défilante de la scène n'a aucune étendue à parcourir : tout tient
/// dans l'écran (F1 à 1280 x 800).
Future<void> theStageNeedsNoScrolling(WidgetTester tester) async {
  final scrollable = find.descendant(
    of: find.byKey(const ValueKey('diagram-stage')),
    matching: find.byType(Scrollable),
  );
  expect(scrollable, findsOneWidget, reason: 'la scène est introuvable');
  final position = tester.state<ScrollableState>(scrollable).position;
  expect(position.maxScrollExtent, 0);
}
