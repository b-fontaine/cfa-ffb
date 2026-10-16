import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I see {15} placement menus
Future<void> iSeePlacementMenus(WidgetTester tester, num count) async {
  final menus = find.byWidgetPredicate(
    (widget) =>
        widget is Tooltip &&
        (widget.message?.startsWith('Placement actions: ') ?? false),
  );
  expect(menus, findsNWidgets(count.toInt()));
}
