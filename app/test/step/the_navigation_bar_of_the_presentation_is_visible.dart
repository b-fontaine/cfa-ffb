import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the navigation bar of the presentation is visible
Future<void> theNavigationBarOfThePresentationIsVisible(
  WidgetTester tester,
) async {
  final bar = find.byKey(const ValueKey('presentation-bottom-bar'));
  expect(bar, findsOneWidget, reason: 'la barre basse est absente');
  final rect = tester.getRect(bar);
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(rect.bottom, lessThanOrEqualTo(screen.height + 0.5));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(screen.width + 0.5));
}
