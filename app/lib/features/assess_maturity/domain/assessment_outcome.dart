import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'assessment_outcome.freezed.dart';

/// Résultat de l'enregistrement d'un bilan de maturité.
@freezed
abstract class AssessmentOutcome with _$AssessmentOutcome {
  const factory AssessmentOutcome({
    required MaturityAssessment assessment,

    /// Aide à la décision uniquement : ne modifie jamais le public `[U]`.
    required bool readinessHint,

    /// Public de l'élève après l'enregistrement (inchangé).
    required Audience audience,
  }) = _AssessmentOutcome;
}
