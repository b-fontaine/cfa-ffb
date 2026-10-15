import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the control {'Fewer failures before an alert'} is enabled
Future<void> theControlIsEnabled(WidgetTester tester, String tooltip) async {
  final button = find.ancestor(
    of: find.byTooltip(tooltip),
    matching: find.byType(IconButton),
  );
  expect(
    tester.widget<IconButton>(button.first).onPressed,
    isNotNull,
    reason: 'le contrôle « $tooltip » devrait être actif',
  );
}
