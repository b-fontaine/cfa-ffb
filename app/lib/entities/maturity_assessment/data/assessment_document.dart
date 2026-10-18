import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/data_owner.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';

/// Correspondance bilan de maturité <-> document `clubs/{c}/assessments/{id}`
/// (liste blanche de `assessmentShape` + `studentOwned` : trois notes de 1 à 4
/// et une remarque libre de 500 caractères au plus, seul texte libre, signalé
/// à l'AIPD). Jamais lisible par un parent ou un élève.
abstract final class AssessmentDocument {
  static Fields encode(MaturityAssessment assessment, DataOwner owner) => {
    'groupId': owner.group.value,
    'seasonId': owner.season.value,
    'studentId': assessment.studentId.value,
    'date': DocumentValues.encodeDate(assessment.date),
    'concentration': assessment.concentration,
    'endurance': assessment.endurance,
    'frustration': assessment.frustration,
    'comment': assessment.comment,
  };

  static MaturityAssessment decode(StoredDocument document) {
    final values = DocumentValues(document.path, document.fields);
    try {
      return MaturityAssessment(
        id: AssessmentId(document.id),
        studentId: StudentId(values.string('studentId')),
        date: values.date('date'),
        concentration: values.integer('concentration', fallback: 0),
        endurance: values.integer('endurance', fallback: 0),
        frustration: values.integer('frustration', fallback: 0),
        comment: values.optString('comment'),
      );
    } on InvariantViolation catch (violation) {
      throw ServiceFailure(
        ServiceFailureCode.other,
        'malformed document ${document.path}: ${violation.code.name}',
      );
    }
  }

  /// Ordre canonique : jour, puis identifiant.
  static int compare(MaturityAssessment a, MaturityAssessment b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.id.value.compareTo(b.id.value);
  }
}
