import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/data_owner.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';

/// Correspondance passage <-> document `clubs/{c}/attempts/{id}` (liste blanche
/// de `attemptShape` + `studentOwned` : groupe, saison et élève dénormalisés,
/// séance, exercice, jour, billes, date de création du **serveur**).
///
/// **Un document par passage** (ADR 0024, décision 17) : le rang n'est pas
/// stocké, il se dérive de l'ordre d'enregistrement (`createdAt` du serveur,
/// puis `recordedAt` de l'appareil, puis identifiant).
abstract final class AttemptDocument {
  /// Champs d'un **nouveau** passage (les règles exigent `createdAt` =
  /// `request.time` à la création). [recordedAt] est l'horloge de l'appareil,
  /// strictement croissante d'un passage à l'autre : elle garde l'ordre de
  /// saisie tant que le serveur n'a pas acquitté (`createdAt` encore nul à la
  /// lecture), puis ne sert plus qu'à départager des dates serveur égales.
  static Fields encode(
    ExerciseAttempt attempt,
    DataOwner owner, {
    required DateTime recordedAt,
  }) => {
    'groupId': owner.group.value,
    'seasonId': owner.season.value,
    'studentId': attempt.studentId.value,
    'sessionId': attempt.sessionId.value,
    'blockId': attempt.exercise.blockId,
    'exerciseNumber': attempt.exercise.number,
    'date': DocumentValues.encodeDate(attempt.date),
    'potted': attempt.potted,
    'total': attempt.total,
    'createdAt': serverTimestamp,
    'recordedAt': recordedAt,
  };

  /// Les seuls champs d'une **correction** en place (les règles refusent tout
  /// autre champ, `createdAt` compris).
  static Fields correction(ExerciseAttempt attempt) => {
    'potted': attempt.potted,
    'total': attempt.total,
  };

  static ExerciseAttempt decode(StoredDocument document) {
    final values = DocumentValues(document.path, document.fields);
    try {
      return ExerciseAttempt(
        id: AttemptId(document.id),
        studentId: StudentId(values.string('studentId')),
        sessionId: SessionId(values.string('sessionId')),
        exercise: ExerciseRef(
          blockId: values.string('blockId'),
          number: values.integer('exerciseNumber', fallback: -1),
        ),
        date: values.date('date'),
        potted: values.integer('potted', fallback: -1),
        total: values.integer('total', fallback: 0),
      );
    } on InvariantViolation catch (violation) {
      throw ServiceFailure(
        ServiceFailureCode.other,
        'malformed document ${document.path}: ${violation.code.name}',
      );
    }
  }

  /// Date d'enregistrement du serveur ; `null` tant que l'écriture locale
  /// n'est pas acquittée (le passage est alors le plus récent).
  static DateTime? createdAt(StoredDocument document) =>
      DocumentValues(document.path, document.fields).optDate('createdAt');

  /// Date d'enregistrement de l'appareil qui a saisi le passage.
  static DateTime? recordedAt(StoredDocument document) =>
      DocumentValues(document.path, document.fields).optDate('recordedAt');

  /// Ordre d'enregistrement : `createdAt` du serveur (une date encore inconnue,
  /// écriture locale en attente, vient après toute date connue), puis
  /// `recordedAt` (l'ordre de saisie de l'appareil, que l'attente de l'accusé
  /// ne perturbe pas), puis l'identifiant. Deux appareils qui lisent les mêmes
  /// documents rendent le même ordre.
  static int compare(StoredDocument a, StoredDocument b) {
    final byCreated = _byDate(createdAt(a), createdAt(b), nullLast: true);
    if (byCreated != 0) return byCreated;
    final byRecorded = _byDate(recordedAt(a), recordedAt(b), nullLast: false);
    if (byRecorded != 0) return byRecorded;
    return a.id.compareTo(b.id);
  }

  static int _byDate(DateTime? x, DateTime? y, {required bool nullLast}) {
    if (x == null && y == null) return 0;
    if (x == null) return nullLast ? 1 : -1;
    if (y == null) return nullLast ? -1 : 1;
    return x.compareTo(y);
  }
}
