import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the session {'demi-bille-1'} shows the minor badge
/// {'Game link rule: proposal'}
///
/// Le badge neutre d'une proposition mineure : signalée, jamais « à valider ».
Future<void> theSessionShowsTheMinorBadge(
  WidgetTester tester,
  String id,
  String label,
) async {
  final badge = find.descendant(
    of: find.byKey(ValueKey('sheet:$id')),
    matching: find.widgetWithText(StatusBadge, label),
  );
  expect(badge, findsOneWidget, reason: 'aucun badge « $label » sur $id');
  expect(tester.widget<StatusBadge>(badge).tone, BadgeTone.neutral);
}
