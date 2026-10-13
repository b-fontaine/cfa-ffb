import 'dart:ui';

import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';

/// Les six poches, avec leur position dans le repère de la table.
///
/// Dérivées de [DiagramPocket] (source unique des coordonnées).
enum TablePocket {
  tl(DiagramPocket.tl),
  tm(DiagramPocket.tm),
  tr(DiagramPocket.tr),
  bl(DiagramPocket.bl),
  bm(DiagramPocket.bm),
  br(DiagramPocket.br);

  TablePocket(this.source);

  /// Poche du modèle de schéma correspondante.
  final DiagramPocket source;

  /// Centre de la poche en cases (`x` ∈ [0, 8], `y` ∈ [0, 4]).
  Offset get position => Offset(source.point.x, source.point.y);
}

/// Passage entre le repère de la table (en cases) et les pixels.
///
/// Repère : `x` ∈ [0, 8] le long de la table (départ à gauche), `y` ∈ [0, 4]
/// en travers (haut → bas), origine au coin haut-gauche de la surface de jeu.
/// Une unité vaut une case de la grille pointillée des fiches fédérales.
/// Voir `docs/knowledge/03-exercices/diagrammes/FORMAT.md`.
class TableGeometry {
  const TableGeometry({required this.surface});

  /// Ajuste une table (surface 2:1 + rails) dans [available], centrée.
  factory TableGeometry.fitting(Size available) {
    const totalWidth = columns + 2 * railWidth;
    const totalHeight = rows + 2 * railWidth;
    final unit = available.isEmpty
        ? 0.0
        : (available.width / totalWidth < available.height / totalHeight
              ? available.width / totalWidth
              : available.height / totalHeight);
    final origin = Offset(
      (available.width - totalWidth * unit) / 2 + railWidth * unit,
      (available.height - totalHeight * unit) / 2 + railWidth * unit,
    );
    return TableGeometry(
      surface: Rect.fromLTWH(origin.dx, origin.dy, columns * unit, rows * unit),
    );
  }

  /// Nombre de cases dans la longueur.
  static const double columns = DiagramLayout.columns;

  /// Nombre de cases dans la largeur.
  static const double rows = DiagramLayout.rows;

  /// Position de la ligne de départ (`[Prop]`, voir FORMAT.md).
  static const double headStringX = DiagramLayout.headStringX;

  /// Rayon d'une bille, en cases (`[Prop]` : 50,8 mm sur ≈ 0,9 m).
  static const double ballRadius = DiagramLayout.ballRadius;

  /// Épaisseur des rails autour de la surface, en cases (`[Prop]`).
  static const double railWidth = 0.5;

  /// Surface de jeu en pixels (bord intérieur des bandes).
  final Rect surface;

  /// Côté d'une case en pixels.
  double get unit => surface.width / columns;

  /// Rayon d'une bille en pixels.
  double get ballRadiusPx => ballRadius * unit;

  /// Table entière (surface + rails) en pixels.
  Rect get tableRect => surface.inflate(railWidth * unit);

  /// Position en pixels d'un point du repère de la table.
  Offset toPixel(Offset table) => surface.topLeft + table * unit;

  /// Position dans le repère de la table d'un point en pixels.
  Offset toTable(Offset pixel) {
    final u = unit;
    if (u == 0) return Offset.zero;
    return (pixel - surface.topLeft) / u;
  }

  /// Centre d'une poche en pixels.
  Offset pocketCenter(TablePocket pocket) => toPixel(pocket.position);

  /// Carré englobant une bille posée en [table] (pour `Positioned.fromRect`).
  Rect ballRect(Offset table) =>
      Rect.fromCircle(center: toPixel(table), radius: ballRadiusPx);
}
