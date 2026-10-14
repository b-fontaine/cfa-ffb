import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'block_acquisition.freezed.dart';

/// Bloc entier déclaré acquis par l'animateur lors du positionnement d'un
/// élève (ADR 0008). Ce n'est ni un passage ni un résultat : aucun passage
/// fictif n'est créé, la dérivation du suivi le lit à part.
///
/// [date] est le jour du positionnement (normalisé par `.dateOnly`) ;
/// l'existence du bloc dans le catalogue se vérifie dans le cas d'usage.
@freezed
abstract class BlockAcquisition with _$BlockAcquisition {
  factory BlockAcquisition({
    required AcquisitionId id,
    required StudentId studentId,
    required String blockId,
    required DateTime date,
    required AcquisitionSource source,
  }) = _BlockAcquisition;

  BlockAcquisition._() {
    if (blockId.trim().isEmpty) {
      throw const InvariantViolation(InvariantCode.invalidExerciseRef);
    }
    if (date != date.dateOnly) {
      throw const InvariantViolation(InvariantCode.invalidRange);
    }
  }
}
