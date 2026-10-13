import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_spec.freezed.dart';

/// Pont utilisé pour l'exercice (mention de la fiche, quand elle existe).
enum Bridge { frame, surface }

/// Un exercice du catalogue : taux requis et variantes `[S]` (ou `[Prop]` pour
/// les exercices d'un bloc proposé, voir [Provenance]).
@freezed
abstract class ExerciseSpec with _$ExerciseSpec {
  const factory ExerciseSpec({
    required ExerciseRef ref,
    required SuccessRate rate,
    Bridge? bridge,
    @Default(false) bool bronze,
    String? note,
    @Default(Provenance.s) Provenance source,
  }) = _ExerciseSpec;

  const ExerciseSpec._();

  /// Vrai pour un exercice proposé `[Prop]`, non fédéral.
  bool get isProposal => source == Provenance.prop;
}
