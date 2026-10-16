import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the session {'demi-bille-1'} is not marked to validate
Future<void> theSessionIsNotMarkedToValidate(
  WidgetTester tester,
  String id,
) async {
  expect(find.byKey(ValueKey('sheet:$id')), findsOneWidget);
  expect(find.byKey(ValueKey('review-badge:$id')), findsNothing);
}
