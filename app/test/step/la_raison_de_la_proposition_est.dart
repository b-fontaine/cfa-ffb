import 'package:billard_cfa/features/suggest_session/domain/sheet_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la raison de la proposition est {'partie suivante'}
Future<void> laRaisonDeLaPropositionEst(
  WidgetTester tester,
  String reason,
) async {
  final expected = switch (reason) {
    'exercice de tête' => SheetSuggestionKind.coversHead,
    'partie suivante' => SheetSuggestionKind.nextPending,
    'déjà donnée' => SheetSuggestionKind.repeat,
    _ => throw ArgumentError('raison inconnue : $reason'),
  };
  expect(TrackingWorld.current.plan.sheet?.kind, expected);
}
