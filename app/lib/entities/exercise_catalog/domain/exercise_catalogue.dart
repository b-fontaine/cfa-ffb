import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/training_block.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_catalogue.freezed.dart';

/// Catalogue immuable des exercices d'entraînement (niveau 1, Blackball).
///
/// `blocks` est trié par `teachingOrder` strictement croissant (ordre
/// d'enseignement `[U]`, distinct de l'ordre du fichier source).
@freezed
abstract class ExerciseCatalogue with _$ExerciseCatalogue {
  factory ExerciseCatalogue({
    required int version,
    required int level,
    required int defaultPassesRequired,
    required List<TrainingBlock> blocks,
  }) = _ExerciseCatalogue;

  ExerciseCatalogue._() {
    if (blocks.isEmpty || defaultPassesRequired < 1) {
      throw const InvariantViolation(InvariantCode.invalidCatalogue);
    }
    final ids = blocks.map((block) => block.id).toSet();
    final ordered = List.generate(
      blocks.length - 1,
      (index) => blocks[index].teachingOrder < blocks[index + 1].teachingOrder,
    ).every((ok) => ok);
    if (ids.length != blocks.length || !ordered) {
      throw const InvariantViolation(InvariantCode.invalidCatalogue);
    }
  }

  /// Tous les exercices, dans l'ordre d'enseignement.
  List<ExerciseSpec> get exercises => [
    for (final block in blocks) ...block.exercises,
  ];

  /// Taux requis par exercice (entrée des dérivations de résultats).
  Map<ExerciseRef, SuccessRate> get rates => {
    for (final spec in exercises) spec.ref: spec.rate,
  };

  TrainingBlock? blockById(String id) {
    for (final block in blocks) {
      if (block.id == id) return block;
    }
    return null;
  }

  ExerciseSpec? exercise(ExerciseRef ref) =>
      blockById(ref.blockId)?.exercises.elementAtOrNull(ref.number - 1);

  /// Premier exercice non validé dans l'ordre d'enseignement ; `null` si le
  /// niveau est terminé. On ne saute jamais un exercice non validé.
  ExerciseRef? nextExercise({required Set<ExerciseRef> validated}) {
    for (final spec in exercises) {
      if (!validated.contains(spec.ref)) return spec.ref;
    }
    return null;
  }
}
