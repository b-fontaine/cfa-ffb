import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> unAppareilRetardataireAjouteUnPassagePour(
  WidgetTester tester,
  String name,
) async {
  final world = OperationsWorld.current;
  // Cet appareil a sa propre connexion : la coupure de l'autre ne le
  // concerne pas.
  final cut = world.store.failAfterBatches;
  world.store.failAfterBatches = null;
  try {
    await world.attempts.add(
      ExerciseAttempt(
        id: const AttemptId('retardataire'),
        studentId: OperationsWorld.studentId(name),
        sessionId: SessionId(world.firstRecord[name]!),
        exercise: ExerciseRef(blockId: 'puissance', number: 1),
        date: DateTime(2026, 10, 6),
        potted: 3,
        total: 5,
      ),
    );
    world.lastWriteRefused = false;
  } on ServiceFailure catch (failure) {
    world.lastWriteRefused = failure.code == ServiceFailureCode.denied;
  } finally {
    world.store.failAfterBatches = cut;
  }
}
