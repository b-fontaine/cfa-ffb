import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'maturity_assessment.freezed.dart';

/// Bilan de maturité d'un élève : trois critères notés de 1 à 4 `[U]` pour
/// l'échelle `[Prop]`. C'est une aide à la décision, jamais un déclencheur.
@freezed
abstract class MaturityAssessment with _$MaturityAssessment {
  factory MaturityAssessment({
    required AssessmentId id,
    required StudentId studentId,
    required DateTime date,
    required int concentration,
    required int endurance,
    required int frustration,

    /// Remarque libre de l'animateur (facultative, 500 caractères au plus).
    String? comment,
  }) = _MaturityAssessment;

  MaturityAssessment._() {
    final scores = [concentration, endurance, frustration];
    if (scores.any((score) => score < minScore || score > maxScore)) {
      throw const InvariantViolation(InvariantCode.scoreOutOfRange);
    }
    if ((comment?.length ?? 0) > maxCommentLength) {
      throw const InvariantViolation(InvariantCode.commentTooLong);
    }
  }

  static const minScore = 1;
  static const maxScore = 4;

  /// Longueur maximale de [comment] (données minimales, élèves mineurs).
  static const maxCommentLength = 500;

  /// Aide : vrai si les trois critères atteignent le seuil de la configuration.
  /// N'entraîne jamais de changement de public `[U]`.
  bool readinessHint(RulesConfig config) =>
      concentration >= config.readinessMinScore &&
      endurance >= config.readinessMinScore &&
      frustration >= config.readinessMinScore;
}
