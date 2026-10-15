import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: every label is at least {16} px
Future<void> everyLabelIsAtLeastPx(WidgetTester tester, num size) async {
  final sizes = DiagramWorld.labelFontSizes(tester);
  expect(sizes, isNotEmpty);
  expect(sizes, everyElement(greaterThanOrEqualTo(size)));
}
