import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'alert_acknowledgement.freezed.dart';

/// « Vu » de l'animateur sur l'alerte d'un élève pour un exercice (ADR 0013).
///
/// L'acquittement est lié au dernier passage de l'exercice au moment du « Vu »
/// ([lastAttemptId]) : tout nouveau passage, ou la suppression de ce passage,
/// fait réapparaître l'alerte. Ce n'est ni un passage ni un résultat : les
/// courbes, les échecs consécutifs et la validation ne le voient pas (même
/// esprit que `BlockAcquisition`, ADR 0008).
///
/// [date] est le jour du « Vu » (normalisé par `.dateOnly`) ; l'existence de
/// l'élève et de l'exercice se vérifie dans le cas d'usage.
@freezed
abstract class AlertAcknowledgement with _$AlertAcknowledgement {
  factory AlertAcknowledgement({
    required AcknowledgementId id,
    required StudentId studentId,
    required ExerciseRef exercise,
    required AttemptId lastAttemptId,
    required DateTime date,
  }) = _AlertAcknowledgement;

  AlertAcknowledgement._() {
    if (date != date.dateOnly) {
      throw const InvariantViolation(InvariantCode.invalidRange);
    }
  }
}
