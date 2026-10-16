import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/session_range.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/training_block.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:flutter_test/flutter_test.dart';

ExerciseRef ref(String block, int number) =>
    ExerciseRef(blockId: block, number: number);

/// Taux par défaut des fixtures : 3 billes sur 5.
SuccessRate rate([int successes = 3, int attempts = 5]) =>
    SuccessRate(successes: successes, attempts: attempts);

DateTime day(int dayOfMonth) => DateTime(2026, 10, dayOfMonth);

ExerciseAttempt attempt(
  ExerciseRef exercise, {
  required int potted,
  int total = 5,
  int dayOfMonth = 1,
  int passIndex = 1,
  String student = 's1',
  String session = 'x1',
  String id = 'a1',
}) => ExerciseAttempt(
  id: AttemptId(id),
  studentId: StudentId(student),
  sessionId: SessionId(session),
  exercise: exercise,
  date: day(dayOfMonth),
  passIndex: passIndex,
  potted: potted,
  total: total,
);

/// Bloc [blockId] marqué acquis au positionnement le [day] octobre 2026.
BlockAcquisition acquisition(
  String blockId, {
  int day = 1,
  String student = 's1',
  String id = 'q1',
}) => BlockAcquisition(
  id: AcquisitionId(id),
  studentId: StudentId(student),
  blockId: blockId,
  date: DateTime(2026, 10, day),
  source: AcquisitionSource.placement,
);

/// « Vu » de l'animateur sur l'alerte de [exercise], rattaché au passage
/// [lastAttempt], le [day] octobre 2026.
AlertAcknowledgement acknowledgement(
  ExerciseRef exercise, {
  required String lastAttempt,
  int day = 5,
  String student = 's1',
  String id = 'k1',
}) => AlertAcknowledgement(
  id: AcknowledgementId(id),
  studentId: StudentId(student),
  exercise: exercise,
  lastAttemptId: AttemptId(lastAttempt),
  date: DateTime(2026, 10, day),
);

TrainingBlock block(
  String id,
  int order, {
  int exercises = 3,
  SuccessRate? successRate,
  int minSessions = 1,
  int maxSessions = 2,
  Provenance source = Provenance.s,
}) => TrainingBlock(
  id: id,
  title: 'Bloc $id',
  teachingOrder: order,
  recommendedSessions: SessionRange(min: minSessions, max: maxSessions),
  technicalSheets: [order],
  source: source,
  exercises: [
    for (var n = 1; n <= exercises; n++)
      ExerciseSpec(
        ref: ref(id, n),
        rate: successRate ?? rate(),
        source: source,
      ),
  ],
);

/// Catalogue de test : blocs `a` (ordre 1), `b` (2), `c` (3), 3 exercices
/// chacun, taux 3/5.
ExerciseCatalogue buildCatalogue([List<TrainingBlock>? blocks]) =>
    ExerciseCatalogue(
      version: 1,
      level: 1,
      defaultPassesRequired: 5,
      blocks: blocks ?? [block('a', 1), block('b', 2), block('c', 3)],
    );

/// Attend un [InvariantViolation] de code [code].
Matcher violation(InvariantCode code) =>
    throwsA(isA<InvariantViolation>().having((e) => e.code, 'code', code));
