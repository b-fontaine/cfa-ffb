import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/session_range.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'training_block.freezed.dart';

/// Un bloc d'entraînement (une notion) et ses exercices numérotés de 1 à n.
///
/// Un bloc `proposal` `[Prop]` n'existe pas dans les PDF fédéraux : tous ses
/// exercices sont des propositions (même [source]).
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
    @Default(Provenance.s) Provenance source,
  }) = _TrainingBlock;

  TrainingBlock._() {
    final contiguous = List.generate(
      exercises.length,
      (index) =>
          exercises[index].ref.blockId == id &&
          exercises[index].ref.number == index + 1,
    ).every((ok) => ok);
    final sameSource = exercises.every((spec) => spec.source == source);
    if (title.trim().isEmpty ||
        teachingOrder < 1 ||
        exercises.isEmpty ||
        !contiguous ||
        !sameSource) {
      throw const InvariantViolation(InvariantCode.invalidCatalogue);
    }
  }

  /// Vrai pour un bloc proposé `[Prop]`, non fédéral.
  bool get isProposal => source == Provenance.prop;
}
