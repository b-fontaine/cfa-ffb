import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the phase {'game'} is on screen
Future<void> thePhaseIsOnScreen(WidgetTester tester, String phase) async {
  final finder = find.byKey(ValueKey('phase:$phase'));
  expect(finder, findsOneWidget);
  final top = tester.getTopLeft(finder).dy;
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  expect(top, inInclusiveRange(0, height), reason: 'phase $phase hors écran');
}
