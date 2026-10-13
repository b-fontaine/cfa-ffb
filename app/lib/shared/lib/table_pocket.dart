import 'dart:math' show Point;

/// Les six poches de la table, dans le repère des schémas (cases : `x` ∈ [0, 8]
/// le long de la table, `y` ∈ [0, 4] en travers, origine en haut à gauche).
enum TablePocket {
  tl(Point(0, 0)),
  tm(Point(4, 0)),
  tr(Point(8, 0)),
  bl(Point(0, 4)),
  bm(Point(4, 4)),
  br(Point(8, 4));

  TablePocket(this.point);

  /// Centre de la poche.
  final Point<double> point;
}
