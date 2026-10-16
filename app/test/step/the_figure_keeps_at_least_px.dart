import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the figure keeps at least {160} px
Future<void> theFigureKeepsAtLeastPx(WidgetTester tester, num minimum) async {
  final figure = find.byKey(const ValueKey('diagram-stage-figure'));
  expect(figure, findsOneWidget, reason: 'la zone du schéma est absente');
  expect(
    tester.getSize(figure).height,
    greaterThanOrEqualTo(minimum.toDouble() - 0.5),
  );
}
