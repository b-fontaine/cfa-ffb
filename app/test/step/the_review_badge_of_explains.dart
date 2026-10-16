import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the review badge of {'posture-1'} explains {'Exercises to validate'}
///
/// Le détail du badge est dans son infobulle ET dans sa sémantique : le survol
/// n'est jamais la seule voie.
Future<void> theReviewBadgeOfExplains(
  WidgetTester tester,
  String id,
  String reason,
) async {
  final badge = find.byKey(ValueKey('review-badge:$id'));
  expect(badge, findsOneWidget, reason: 'badge de relecture absent de $id');
  final tooltip = tester.widget<Tooltip>(
    find.ancestor(of: badge, matching: find.byType(Tooltip)).first,
  );
  expect(tooltip.message, contains(reason));
  final handle = tester.ensureSemantics();
  expect(tester.getSemantics(badge).label, contains(reason));
  handle.dispose();
}
