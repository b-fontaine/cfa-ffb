import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'diagram_library.freezed.dart';

/// Ensemble immuable des schémas transcrits, dans l'ordre de chargement
/// (dossier puis page).
@freezed
abstract class DiagramLibrary with _$DiagramLibrary {
  factory DiagramLibrary(List<ExerciseDiagram> diagrams) = _DiagramLibrary;

  DiagramLibrary._() {
    final ids = diagrams.map((diagram) => diagram.id).toSet();
    if (ids.length != diagrams.length) {
      throw const InvariantViolation(InvariantCode.invalidDiagram);
    }
  }

  /// Schéma d'identifiant [id] ; `null` s'il n'existe pas.
  ExerciseDiagram? byId(String id) {
    for (final diagram in diagrams) {
      if (diagram.id == id) return diagram;
    }
    return null;
  }

  /// Schémas de la clé [key], dans l'ordre des pages. Plusieurs quand la source
  /// répète la fiche (le rejet naturel apparaît deux fois à l'entraînement) ;
  /// vide quand la source n'a pas de schéma pour cet exercice.
  List<ExerciseDiagram> find(DiagramKey key) => [
    for (final diagram in diagrams)
      if (diagram.key == key) diagram,
  ];
}
