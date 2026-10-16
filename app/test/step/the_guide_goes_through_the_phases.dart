import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the guide goes through the phases
/// {'welcome,notionAndInitiation,training,game,review'}
///
/// Parcourt la séance guidée avec « Suivant » jusqu'à la dernière étape et
/// relève, dans l'ordre, les phases affichées (la dernière étape propose
/// « Finish » à la place de « Next »).
Future<void> theGuideGoesThroughThePhases(
  WidgetTester tester,
  String phases,
) async {
  final seen = <String>[];
  var guard = 0;
  while (true) {
    final shown = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith('phase:');
    });
    expect(shown, findsOneWidget);
    final phase = (shown.evaluate().single.widget.key! as ValueKey<String>)
        .value
        .substring('phase:'.length);
    if (seen.isEmpty || seen.last != phase) seen.add(phase);
    // Sur la dernière étape, « Suivant » devient « Finish ».
    if (find.text('Finish').evaluate().isNotEmpty) break;
    final next = find.ancestor(
      of: find.text('Next'),
      matching: find.bySubtype<ButtonStyleButton>(),
    );
    expect(next, findsOneWidget);
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(++guard, lessThan(60), reason: 'trop d’étapes');
  }
  expect(seen, phases.split(','));
}
