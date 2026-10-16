import 'package:billard_cfa/entities/exercise_result/domain/technique_summary.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'path_row.freezed.dart';

/// Une ligne du parcours de l'élève : une technique (un bloc du catalogue)
/// et ses cases, une par exercice.
@freezed
abstract class PathRow with _$PathRow {
  const factory PathRow({
    required String blockId,
    required String title,

    /// Bloc proposé `[Prop]`, jamais présenté comme fédéral.
    required bool proposal,
    required TechniqueSummary summary,

    /// Jour du positionnement quand le bloc est marqué acquis (y compris
    /// partiellement repris par des passages) ; sinon `null`.
    required DateTime? acquiredOn,

    /// Exercices du bloc repris par des passages depuis le positionnement.
    required int resumedCount,
  }) = _PathRow;
}
