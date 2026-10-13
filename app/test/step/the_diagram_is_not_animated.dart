import 'package:flutter_test/flutter_test.dart';

/// Usage: the diagram is not animated
Future<void> theDiagramIsNotAnimated(WidgetTester tester) async {
  expect(tester.hasRunningAnimations, isFalse);
}
