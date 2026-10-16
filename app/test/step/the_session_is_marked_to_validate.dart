import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the session {'posture-1'} is marked to validate
///
/// Une séance à valider porte le badge unique de relecture.
Future<void> theSessionIsMarkedToValidate(
  WidgetTester tester,
  String id,
) async {
  expect(find.byKey(ValueKey('sheet:$id')), findsOneWidget);
  expect(find.byKey(ValueKey('review-badge:$id')), findsOneWidget);
}
