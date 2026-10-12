import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Port d'accès aux bilans de maturité (implémenté dans la couche data).
///
/// [add] d'un id déjà connu remplace le bilan (idempotent) ; la suppression
/// est logique.
abstract interface class AssessmentRepository {
  Future<void> add(MaturityAssessment assessment);

  /// Bilans de l'élève, du plus ancien au plus récent.
  Future<List<MaturityAssessment>> forStudent(StudentId studentId);

  /// Tous les bilans, dans l'ordre d'enregistrement.
  Future<List<MaturityAssessment>> all();

  /// Supprime logiquement le bilan ; sans effet s'il n'existe pas.
  Future<void> delete(AssessmentId id);

  /// Efface physiquement tous les bilans de l'élève (droit à l'effacement),
  /// y compris ceux supprimés logiquement.
  Future<void> eraseStudent(StudentId studentId);
}
