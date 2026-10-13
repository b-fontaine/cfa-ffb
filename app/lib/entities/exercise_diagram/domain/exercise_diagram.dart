import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_key.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

export 'package:billard_cfa/entities/exercise_diagram/domain/diagram_key.dart';

part 'exercise_diagram.freezed.dart';

/// Chevalet indiqué par l'énoncé (FORMAT : `bridge`).
enum DiagramBridge { frame, surface, none, unknown }

/// Schéma de table d'un exercice, d'un jeu ou d'une fiche d'initiation,
/// transcrit d'un PDF `[S]` (`docs/knowledge/03-exercices/diagrammes/`).
@freezed
abstract class ExerciseDiagram with _$ExerciseDiagram {
  const factory ExerciseDiagram({
    /// Identifiant unique de la transcription (`entrainement-p03-e1`).
    required String id,
    required DiagramKind kind,

    /// Titre de la fiche, tel qu'écrit dans le PDF.
    required String sheet,

    /// Texte du PDF.
    required String caption,

    /// Description écrite pour un lecteur qui ne voit pas le schéma.
    required String description,
    required String sourceFile,
    required int sourcePage,
    required DiagramTable table,

    /// Numéro d'exercice dans la fiche, quand la page en porte un.
    int? exercise,

    /// Taux indiqué sur la fiche (réussites, tentatives).
    SuccessRate? successRate,
    DiagramBridge? bridge,
    @Default(false) bool bronze,
    @Default(<String>[]) List<String> annotations,

    /// Ce que la transcription n'a pas pu lire avec certitude.
    @Default(<String>[]) List<String> uncertainties,
  }) = _ExerciseDiagram;

  const ExerciseDiagram._();

  /// Clé de recherche du schéma.
  DiagramKey get key =>
      DiagramKey(kind: kind, sheet: sheet, exercise: exercise);

  /// Quantités de bille des tirs, sans doublon, dans l'ordre des tirs. Les
  /// tirs sans quantité précisée sont ignorés ; vide quand aucune n'est donnée.
  List<TableContact> get contacts {
    final found = <TableContact>[];
    for (final step in table.steps) {
      final contact = step.contact;
      if (contact != null && !found.contains(contact)) found.add(contact);
    }
    return found;
  }
}
