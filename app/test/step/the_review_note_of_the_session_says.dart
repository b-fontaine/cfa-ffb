import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the review note of the session says {'2 points to validate'}
Future<void> theReviewNoteOfTheSessionSays(
  WidgetTester tester,
  String heading,
) async {
  expect(find.byKey(const ValueKey('review-note')), findsOneWidget);
  expect(
    find.descendant(
      of: find.byKey(const ValueKey('review-note')),
      matching: find.text(heading),
    ),
    findsOneWidget,
  );
}
