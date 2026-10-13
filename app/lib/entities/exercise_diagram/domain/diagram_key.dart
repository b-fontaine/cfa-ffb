import 'package:freezed_annotation/freezed_annotation.dart';

part 'diagram_key.freezed.dart';

/// Famille de fiches d'où vient le schéma (FORMAT : `kind` des diagrammes à
/// table).
enum DiagramKind { exercise, game, initiation }

/// Clé de recherche : (famille, titre de fiche, numéro d'exercice).
///
/// Le titre est celui du PDF ; pour l'entraînement il est identique au titre du
/// bloc du catalogue (`TrainingBlock.title`), ce qui relie les deux par les
/// données. Sans numéro (`exercise` nul), la clé désigne les schémas de la
/// fiche qui n'en portent pas.
@freezed
abstract class DiagramKey with _$DiagramKey {
  const factory DiagramKey({
    required DiagramKind kind,
    required String sheet,
    int? exercise,
  }) = _DiagramKey;

  /// Exercice numéroté d'une fiche d'entraînement.
  factory DiagramKey.training({required String sheet, required int exercise}) =>
      DiagramKey(kind: DiagramKind.exercise, sheet: sheet, exercise: exercise);
}
