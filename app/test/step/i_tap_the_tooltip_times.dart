import 'package:flutter_test/flutter_test.dart';

import 'i_tap_the_tooltip.dart';

/// Usage: I tap the tooltip {'Add a point for Player or team A'} {3} times
Future<void> iTapTheTooltipTimes(
  WidgetTester tester,
  String message,
  num times,
) async {
  for (var i = 0; i < times; i++) {
    await iTapTheTooltip(tester, message);
  }
}
