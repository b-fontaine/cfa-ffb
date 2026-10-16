import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the guide header takes at most a quarter of the screen
Future<void> theGuideHeaderTakesAtMostAQuarterOfTheScreen(
  WidgetTester tester,
) async {
  final header = tester.getRect(find.byKey(const ValueKey('guide-header')));
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(header.bottom, lessThanOrEqualTo(screen.height / 4 + 0.5));
}
