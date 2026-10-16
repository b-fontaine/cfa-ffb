import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the session {'demi-bille-1'} has no review badge
///
/// Le badge « n points à valider » : les badges neutres des propositions
/// mineures ne sont pas concernés.
Future<void> theSessionHasNoReviewBadge(WidgetTester tester, String id) async {
  expect(find.byKey(ValueKey('sheet:$id')), findsOneWidget);
  expect(find.byKey(ValueKey('review-badge:$id')), findsNothing);
}
