import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';

/// Une technique du catalogue : son rang dans l'ordre d'enseignement et ses
/// séances (« parties ») par partie croissante.
final class TechniqueSheets {
  const TechniqueSheets({
    required this.rank,
    required this.technique,
    required this.sheets,
  });

  /// Rang de la technique, à partir de 1.
  final int rank;

  /// Identifiant de la technique (`demi-bille`).
  final String technique;

  /// Séances de la technique, par partie croissante.
  final List<SessionSheet> sheets;

  /// Nombre de séances de la technique.
  int get partCount => sheets.length;
}

/// Regroupe [sheets] par technique, dans l'ordre d'enseignement : les
/// techniques suivent l'ordre des séances, les séances d'une technique leur
/// partie. Règle unique du catalogue et du planificateur.
List<TechniqueSheets> groupByTechnique(Iterable<SessionSheet> sheets) {
  final ordered = [...sheets]..sort((a, b) => a.order.compareTo(b.order));
  final byTechnique = <String, List<SessionSheet>>{};
  for (final sheet in ordered) {
    byTechnique.putIfAbsent(sheet.technique, () => []).add(sheet);
  }
  return List.unmodifiable([
    for (final (index, entry) in byTechnique.entries.indexed)
      TechniqueSheets(
        rank: index + 1,
        technique: entry.key,
        sheets: List.unmodifiable(entry.value),
      ),
  ]);
}

/// Nombre de séances de [technique] parmi [sheets] (« séance 2/2 »).
int partCountOf(Iterable<SessionSheet> sheets, String technique) =>
    sheets.where((s) => s.technique == technique).length;

/// Identifiants des diagrammes dont [sheet] a besoin : celui de chaque
/// exercice, ses illustrations `diagram_ref` et celles de la séance
/// précédente [previous] (rappel réutilisé). Règle unique de lecture des
/// schémas, pour le détail et le guide.
Set<String> diagramIdsOf(SessionSheet sheet, SessionSheet? previous) => {
  for (final e in sheet.exercises) e.diagramId,
  ..._diagramRefs(sheet),
  if (previous != null) ..._diagramRefs(previous),
};

Iterable<String> _diagramRefs(SessionSheet sheet) => [
  for (final i in sheet.illustrations)
    if (i is DiagramRefIllustration) i.diagramId,
];
