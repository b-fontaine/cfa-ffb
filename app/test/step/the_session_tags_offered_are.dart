import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the session tags offered are {'Too long,Too short'}
///
/// Les étiquettes proposées dans la zone « Notes de séance », dans l'ordre
/// affiché (liste fermée : rien d'autre n'est proposé).
Future<void> theSessionTagsOfferedAre(
  WidgetTester tester,
  String labels,
) async {
  final zone = find.byKey(const ValueKey('session-tags'));
  expect(zone, findsOneWidget, reason: 'zone des étiquettes absente');
  await tester.ensureVisible(zone);
  await tester.pumpAndSettle();
  final shown = [
    for (final chip in tester.widgetList<FilterChip>(
      find.descendant(of: zone, matching: find.byType(FilterChip)),
    ))
      (chip.label as Text).data,
  ];
  expect(shown, labels.split(','));
}
