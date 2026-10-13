import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';

/// Rayon d'une bille, en cases du repère des schémas `[Prop]` (FORMAT des
/// diagrammes : 0.1).
const double ballRadius = 0.1;

/// Centre de la bille fantôme : `G = O - 2r · unit(P - O)`, où `O` est le
/// centre de la bille cible [object] et `P` celui de [pocket]. Une bille posée
/// exactement sur la poche n'a pas de direction : la bille fantôme est alors
/// la bille cible elle-même.
math.Point<double> ghostBallPosition({
  required math.Point<double> object,
  required TablePocket pocket,
}) {
  final towardsPocket = pocket.point - object;
  final length = math.sqrt(
    towardsPocket.x * towardsPocket.x + towardsPocket.y * towardsPocket.y,
  );
  if (length == 0) {
    return object;
  }
  final unit = math.Point<double>(
    towardsPocket.x / length,
    towardsPocket.y / length,
  );
  return math.Point<double>(
    object.x - 2 * ballRadius * unit.x,
    object.y - 2 * ballRadius * unit.y,
  );
}

/// Angle de coupe `θ` en radians, entre `G - C` (blanche `C` vers la bille
/// fantôme) et `P - O` (bille cible vers la poche), dans `[0, π]`.
double cutAngle({
  required math.Point<double> cue,
  required math.Point<double> object,
  required TablePocket pocket,
}) {
  final ghost = ghostBallPosition(object: object, pocket: pocket);
  final aim = ghost - cue;
  final line = pocket.point - object;
  final cross = aim.x * line.y - aim.y * line.x;
  final dot = aim.x * line.x + aim.y * line.y;
  return math.atan2(cross.abs(), dot);
}

/// Quantité de bille dérivée de la géométrie : `f = 1 - sin θ`, de 1 (bille
/// pleine, `θ = 0`) à 0 (coupe de 90° ou plus, impossible à empocher).
double contactQuantity({
  required math.Point<double> cue,
  required math.Point<double> object,
  required TablePocket pocket,
}) {
  final theta = cutAngle(cue: cue, object: object, pocket: pocket);
  return theta >= math.pi / 2 ? 0 : 1 - math.sin(theta);
}

/// Écart toléré entre la quantité dérivée de la géométrie et l'étiquette d'un
/// `ghost_aim` (FORMAT § 6, règle V17).
const double ghostAimTolerance = 0.07;

/// Écart absolu entre la quantité dérivée de la géométrie et celle de
/// l'étiquette [fraction].
double ghostAimDeviation({
  required math.Point<double> cue,
  required math.Point<double> object,
  required TablePocket pocket,
  required ContactFraction fraction,
}) {
  final quantity = contactQuantity(cue: cue, object: object, pocket: pocket);
  return (quantity - fraction.overlap).abs();
}

/// Vrai si l'étiquette [fraction] est cohérente avec la géométrie, à
/// [ghostAimTolerance] près.
bool isGhostAimConsistent({
  required math.Point<double> cue,
  required math.Point<double> object,
  required TablePocket pocket,
  required ContactFraction fraction,
}) =>
    ghostAimDeviation(
      cue: cue,
      object: object,
      pocket: pocket,
      fraction: fraction,
    ) <=
    ghostAimTolerance;
