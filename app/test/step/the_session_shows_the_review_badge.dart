import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the session {'posture-1'} shows the review badge
/// {'2 points to validate'}
Future<void> theSessionShowsTheReviewBadge(
  WidgetTester tester,
  String id,
  String label,
) async {
  final badge = find.byKey(ValueKey('review-badge:$id'));
  expect(badge, findsOneWidget, reason: 'badge de relecture absent de $id');
  expect(tester.widget<StatusBadge>(badge).label, label);
}
