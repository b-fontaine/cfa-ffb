import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the diagram is fully visible without scrolling
///
/// Le schéma et ses commandes sont entre le bas de l'en-tête et le haut de la
/// barre basse, dans l'écran, sans défilement.
Future<void> theDiagramIsFullyVisibleWithoutScrolling(
  WidgetTester tester,
) async {
  final diagram = find.byKey(const ValueKey('step-media'));
  expect(diagram, findsOneWidget, reason: 'aucun schéma à montrer');
  final rect = tester.getRect(diagram);
  final header = tester.getRect(find.byKey(const ValueKey('guide-header')));
  final bar = tester.getRect(find.byKey(const ValueKey('guide-bottom-bar')));
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(rect.top, greaterThanOrEqualTo(header.bottom - 0.5));
  expect(rect.bottom, lessThanOrEqualTo(bar.top + 0.5));
  expect(rect.bottom, lessThanOrEqualTo(screen.height));
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(screen.width + 0.5));
}
