import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_timing.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sheet_detail.freezed.dart';

/// Une séance du catalogue prête à être lue : son contenu, la séance qui la
/// précède, les taux du catalogue d'entraînement, les schémas résolus et le
/// minutage calculé pour chaque public. Lecture seule.
@freezed
abstract class SheetDetail with _$SheetDetail {
  const factory SheetDetail({
    required SessionSheet sheet,

    /// Nombre de séances de la technique (« séance 2/2 »).
    required int partCount,

    /// Minutes calculées `[Prop]`, par public.
    required Map<Audience, SheetTiming> timings,

    /// Séance précédente (`null` pour la première du catalogue) : le rappel
    /// porte sur elle et peut en réutiliser une illustration.
    SessionSheet? previous,

    /// Exercice du catalogue d'entraînement (taux, chevalet, bronze) par
    /// identifiant d'exercice de la séance ; absent si le catalogue ne le
    /// connaît pas.
    @Default(<String, ExerciseSpec>{}) Map<String, ExerciseSpec> exerciseSpecs,

    /// Schémas transcrits par identifiant de diagramme.
    @Default(<String, ExerciseDiagram>{}) Map<String, ExerciseDiagram> diagrams,

    /// Vrai quand les schémas n'ont pas pu être lus : la séance reste lisible.
    @Default(false) bool diagramsUnreadable,
  }) = _SheetDetail;
}
