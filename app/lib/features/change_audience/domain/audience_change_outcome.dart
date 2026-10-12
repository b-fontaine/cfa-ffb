import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'audience_change_outcome.freezed.dart';

/// Avertissement non bloquant lors d'un passage en cours adultes.
enum AudienceChangeWarning { noAssessment, readinessNotIndicated }

/// Élève après le changement de public, et avertissements éventuels.
@freezed
abstract class AudienceChangeOutcome with _$AudienceChangeOutcome {
  const factory AudienceChangeOutcome({
    required Student student,
    required List<AudienceChangeWarning> warnings,
  }) = _AudienceChangeOutcome;
}
