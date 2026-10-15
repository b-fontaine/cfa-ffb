import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the control {'More failures before an alert'} is disabled
Future<void> theControlIsDisabled(WidgetTester tester, String tooltip) async {
  final button = find.ancestor(
    of: find.byTooltip(tooltip),
    matching: find.byType(IconButton),
  );
  expect(
    tester.widget<IconButton>(button.first).onPressed,
    isNull,
    reason: 'le contrôle « $tooltip » devrait être désactivé',
  );
}
