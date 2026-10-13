import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/training_block.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_sheet.freezed.dart';

/// Un exercice du catalogue avec son bloc : de quoi renvoyer à la fiche
/// fédérale source (numéro de fiche technique, taux requis, mention) et au
/// schéma de table de l'exercice.
@freezed
abstract class ExerciseSheet with _$ExerciseSheet {
  const factory ExerciseSheet({
    required TrainingBlock block,
    required ExerciseSpec spec,

    /// Schémas de l'exercice, dans l'ordre des pages. Plusieurs quand la
    /// source répète la fiche (le rejet naturel) ; vide quand la source n'en
    /// a pas.
    @Default(<ExerciseDiagram>[]) List<ExerciseDiagram> diagrams,

    /// Vrai quand les schémas n'ont pas pu être lus : la fiche reste affichée,
    /// seul le schéma est remplacé par un message.
    @Default(false) bool diagramsUnreadable,
  }) = _ExerciseSheet;
}
