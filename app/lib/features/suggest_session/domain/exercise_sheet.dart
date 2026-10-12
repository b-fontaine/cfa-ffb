import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/training_block.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_sheet.freezed.dart';

/// Un exercice du catalogue avec son bloc : de quoi renvoyer à la fiche
/// fédérale source (numéro de fiche technique, taux requis, mention).
@freezed
abstract class ExerciseSheet with _$ExerciseSheet {
  const factory ExerciseSheet({
    required TrainingBlock block,
    required ExerciseSpec spec,
  }) = _ExerciseSheet;
}
