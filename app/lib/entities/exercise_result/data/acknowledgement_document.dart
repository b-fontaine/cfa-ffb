import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/data_owner.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';

/// Correspondance acquittement « Vu » <-> document
/// `clubs/{c}/acknowledgements/{id}` (liste blanche de `acknowledgementShape` +
/// `studentOwned`). L'acquittement est **partagé par club** (ADR 0024, B5) et
/// enregistre **l'identifiant du compte** qui l'a donné (`createdBy`, que les
/// règles font égal à `request.auth.uid` à la création et figent ensuite) : une
/// donnée personnelle d'animateur, déclarée au registre. Jamais lisible par un
/// parent ou un élève.
abstract final class AcknowledgementDocument {
  /// Champs d'un acquittement : [createdBy] n'est donné qu'à la création.
  static Fields encode(
    AlertAcknowledgement acknowledgement,
    DataOwner owner, {
    UserId? createdBy,
  }) => {
    'groupId': owner.group.value,
    'seasonId': owner.season.value,
    'studentId': acknowledgement.studentId.value,
    'blockId': acknowledgement.exercise.blockId,
    'exerciseNumber': acknowledgement.exercise.number,
    'lastAttemptId': acknowledgement.lastAttemptId.value,
    'date': DocumentValues.encodeDate(acknowledgement.date),
    'createdBy': ?createdBy?.value,
  };

  static AlertAcknowledgement decode(StoredDocument document) {
    final values = DocumentValues(document.path, document.fields);
    try {
      return AlertAcknowledgement(
        id: AcknowledgementId(document.id),
        studentId: StudentId(values.string('studentId')),
        exercise: ExerciseRef(
          blockId: values.string('blockId'),
          number: values.integer('exerciseNumber', fallback: -1),
        ),
        lastAttemptId: AttemptId(values.string('lastAttemptId')),
        date: values.date('date'),
      );
    } on InvariantViolation catch (violation) {
      throw ServiceFailure(
        ServiceFailureCode.other,
        'malformed document ${document.path}: ${violation.code.name}',
      );
    }
  }

  /// Ordre canonique : jour du « Vu », puis identifiant.
  static int compare(AlertAcknowledgement a, AlertAcknowledgement b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.id.value.compareTo(b.id.value);
  }
}
