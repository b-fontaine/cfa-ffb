import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the button {'closure-erase-and-close'} is enabled
Future<void> theButtonIsEnabled(WidgetTester tester, String key) async {
  final button = tester.widget<FilledButton>(find.byKey(ValueKey(key)));
  expect(button.onPressed, isNotNull);
}
