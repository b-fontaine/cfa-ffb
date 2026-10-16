import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the review note of the session lists {'exercise,recall,theory'}
///
/// Un motif par ligne (`review-note:<motif>`), dans l'ordre donné.
Future<void> theReviewNoteOfTheSessionLists(
  WidgetTester tester,
  String reasons,
) async {
  final wanted = reasons.split(',');
  final listed = [
    for (final element
        in find
            .byWidgetPredicate(
              (widget) =>
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    'review-note:',
                  ),
            )
            .evaluate())
      (element.widget.key! as ValueKey<String>).value.substring(
        'review-note:'.length,
      ),
  ];
  expect(listed, wanted);
}
