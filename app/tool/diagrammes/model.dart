// Constantes du FORMAT des diagrammes (docs/knowledge/03-exercices/
// diagrammes/FORMAT.md) et types partagés par le validateur et les rendus.

/// Document YAML converti en structures Dart simples.
typedef Json = Map<String, Object?>;

const tableLength = 8.0;
const tableWidth = 4.0;
const ballRadius = 0.1;
const startLineX = 2.0;

/// Bornes tolérées pour les coordonnées (poches, bords).
const minX = -0.5;
const maxX = 8.5;
const minY = -0.5;
const maxY = 4.5;

const diagramKinds = {
  'exercise',
  'game',
  'initiation',
  'technique-schema',
  'technique-photo',
};
const tableKinds = {'exercise', 'game', 'initiation'};
const bridges = {'frame', 'surface', 'none', 'unknown'};
const ballColors = {'red', 'yellow', 'black', 'white'};
const ghostRoles = {'impact', 'cue_start'};
const arrowKinds = {'object', 'cue', 'indication'};
const contacts = {'full', 'three_quarter', 'half', 'quarter', 'thin', 'none'};
const bands = {'top', 'bottom', 'left', 'right'};
const zoneShapes = {'rect', 'polygon', 'circle'};

/// Centres des poches, en cases.
const pockets = <String, List<double>>{
  'tl': [0, 0],
  'tm': [4, 0],
  'tr': [8, 0],
  'bl': [0, 4],
  'bm': [4, 4],
  'br': [8, 4],
};

/// Résultat de la validation d'un fichier.
class ValidationReport {
  ValidationReport({
    this.errors = const [],
    this.warnings = const [],
    this.diagrams = const [],
  });

  final List<String> errors;
  final List<String> warnings;
  final List<Json> diagrams;
}

/// Convertit récursivement un nœud `package:yaml` en Map / List simples.
Object? toPlain(Object? node) {
  if (node is Map) {
    return <String, Object?>{
      for (final e in node.entries) '${e.key}': toPlain(e.value),
    };
  }
  if (node is List) return [for (final v in node) toPlain(v)];
  return node;
}

/// `[x, y]` numérique, ou `null` si [value] n'en est pas un.
List<double>? pointOf(Object? value) {
  if (value is List && value.length == 2) {
    final x = value[0];
    final y = value[1];
    if (x is num && y is num) return [x.toDouble(), y.toDouble()];
  }
  return null;
}

/// Liste d'objets (Map) de [d][key], en ignorant ce qui n'est pas un objet.
List<Json> mapsOf(Json d, String key) {
  final v = d[key];
  if (v is! List) return const [];
  return [
    for (final e in v)
      if (e is Map<String, Object?>) e,
  ];
}

/// Formate un nombre avec au moins une décimale (`3` -> `3.0`).
String fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(1) : v.toString();

/// Formate un point `(x, y)`.
String fmtPoint(List<double> p) => '(${fmt(p[0])}, ${fmt(p[1])})';
