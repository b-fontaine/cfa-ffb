import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/session_range.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'training_block.freezed.dart';

/// Un bloc d'entraînement (une notion) et ses exercices numérotés de 1 à n.
@freezed
abstract class TrainingBlock with _$TrainingBlock {
  factory TrainingBlock({
    required String id,
    required String title,
    required int teachingOrder,
    required SessionRange recommendedSessions,
    required List<int> technicalSheets,
    required List<ExerciseSpec> exercises,
    @Default(false) bool duplicateInSource,
  }) = _TrainingBlock;

  TrainingBlock._() {
    final contiguous = List.generate(
      exercises.length,
      (index) =>
          exercises[index].ref.blockId == id &&
          exercises[index].ref.number == index + 1,
    ).every((ok) => ok);
    if (title.trim().isEmpty ||
        teachingOrder < 1 ||
        exercises.isEmpty ||
        !contiguous) {
      throw const InvariantViolation(InvariantCode.invalidCatalogue);
    }
  }
}
