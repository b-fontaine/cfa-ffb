import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Usage: the screen is {1000} by {800}
Future<void> theScreenIsBy(WidgetTester tester, num width, num height) async {
  tester.view
    ..physicalSize = Size(width.toDouble(), height.toDouble())
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
