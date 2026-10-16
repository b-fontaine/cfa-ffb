import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

const Map<String, String> _reasons = {
  'aucune alerte active': 'alertNotActive',
  'exercice inconnu': 'unknownExercise',
};

/// Usage: l'acquittement est refusé avec le motif {'aucune alerte active'}
Future<void> lacquittementEstRefuseAvecLeMotif(
  WidgetTester tester,
  String reason,
) async {
  final code = _reasons[reason];
  expect(code, isNotNull, reason: 'motif métier inconnu : $reason');
  final result = TrackingWorld.current.lastAcknowledgement;
  expect(
    result,
    isA<Err<Object?>>().having(
      (r) => r.failure,
      'failure',
      isA<InvariantViolation>().having((f) => f.code.name, 'code', code),
    ),
  );
}
