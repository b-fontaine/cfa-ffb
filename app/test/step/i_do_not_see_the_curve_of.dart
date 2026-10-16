import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I do not see the curve of {'puissance 1'}
Future<void> iDoNotSeeTheCurveOf(WidgetTester tester, String exercise) async {
  expect(
    find.byKey(ValueKey('curve-${exercise.replaceAll(' ', '-')}')),
    findsNothing,
  );
}
