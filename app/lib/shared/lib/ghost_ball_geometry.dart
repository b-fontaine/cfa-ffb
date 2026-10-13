import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';

/// Centre de la bille fantôme : `G = O - s · unit(P - O)`, où `O` est le
/// centre de la bille de but [object], `P` celui de [pocket] et
/// `s = r_c + r_o` la distance entre centres d'une blanche et d'une bille de
/// but au contact (la bille fantôme est une **blanche** : rayon `r_c`). Une
/// bille posée exactement sur la poche n'a pas de direction : la bille
/// fantôme est alors la bille de but elle-même.
math.Point<double> ghostBallPosition({
  required math.Point<double> object,
  required TablePocket pocket,
  BallSizes sizes = BallSizes.standard,
}) {
  final towardsPocket = pocket.point - object;
  final length = math.sqrt(
    towardsPocket.x * towardsPocket.x + towardsPocket.y * towardsPocket.y,
  );
  if (length == 0) {
    return object;
  }
  final contact = sizes.ghostDistance;
  return math.Point<double>(
    object.x - contact * towardsPocket.x / length,
    object.y - contact * towardsPocket.y / length,
  );
}

/// Point de contact entre la blanche et la bille de but : `O - r_o · unit(P -
/// O)`, sur la bille de but, côté blanche. `null` si la bille est sur la poche
/// (pas de direction).
math.Point<double>? contactPoint({
  required math.Point<double> object,
  required TablePocket pocket,
  BallSizes sizes = BallSizes.standard,
}) {
  final towardsPocket = pocket.point - object;
  final length = math.sqrt(
    towardsPocket.x * towardsPocket.x + towardsPocket.y * towardsPocket.y,
  );
  if (length == 0) return null;
  return math.Point<double>(
    object.x - sizes.objectRadius * towardsPocket.x / length,
    object.y - sizes.objectRadius * towardsPocket.y / length,
  );
}

/// Angle de coupe `θ` en radians, entre `G - C` (blanche `C` vers la bille
/// fantôme) et `P - O` (bille de but vers la poche), dans `[0, π]`.
double cutAngle({
  required math.Point<double> cue,
  required math.Point<double> object,
  required TablePocket pocket,
  BallSizes sizes = BallSizes.standard,
}) {
  final ghost = ghostBallPosition(object: object, pocket: pocket, sizes: sizes);
  final aim = ghost - cue;
  final line = pocket.point - object;
  final cross = aim.x * line.y - aim.y * line.x;
  final dot = aim.x * line.x + aim.y * line.y;
  return math.atan2(cross.abs(), dot);
}

/// Distance `d = s · sin θ` (cases) entre la ligne de visée et le centre de la
/// bille de but ; `s` si la coupe atteint 90° ou plus.
double aimDistance({
  required math.Point<double> cue,
  required math.Point<double> object,
  required TablePocket pocket,
  BallSizes sizes = BallSizes.standard,
}) {
  final theta = cutAngle(
    cue: cue,
    object: object,
    pocket: pocket,
    sizes: sizes,
  );
  return theta >= math.pi / 2
      ? sizes.ghostDistance
      : sizes.ghostDistance * math.sin(theta);
}

/// Indice continu de la quantité de bille : `1 - sin θ`, de 1 (bille pleine,
/// `θ = 0`) à 0 (coupe de 90° ou plus, impossible à empocher). Ce n'est pas la
/// définition d'une quantité : celle-ci passe par `ContactFraction.aimOffset`.
double contactQuantity({
  required math.Point<double> cue,
  required math.Point<double> object,
  required TablePocket pocket,
  BallSizes sizes = BallSizes.standard,
}) {
  final theta = cutAngle(
    cue: cue,
    object: object,
    pocket: pocket,
    sizes: sizes,
  );
  return theta >= math.pi / 2 ? 0 : 1 - math.sin(theta);
}

/// Part de `s` tolérée entre `d` et la valeur nominale d'une quantité
/// (FORMAT § 6, règle V17) ; deux quantités voisines sont écartées de 0,19 `s`
/// au moins, soit plus de deux tolérances.
const double ghostAimToleranceShare = 0.07;

/// Écart toléré (cases) entre `d` et la valeur nominale de l'étiquette :
/// `0,07 · s` (0,0150 case).
double ghostAimTolerance({BallSizes sizes = BallSizes.standard}) =>
    ghostAimToleranceShare * sizes.ghostDistance;

/// Écart absolu (cases) `|d - d_nominal|` entre la géométrie et l'étiquette
/// [fraction].
double ghostAimDeviation({
  required math.Point<double> cue,
  required math.Point<double> object,
  required TablePocket pocket,
  required ContactFraction fraction,
  BallSizes sizes = BallSizes.standard,
}) {
  final d = aimDistance(cue: cue, object: object, pocket: pocket, sizes: sizes);
  return (d - fraction.aimOffset(sizes)).abs();
}

/// Vrai si l'étiquette [fraction] est cohérente avec la géométrie, à
/// [ghostAimTolerance] près.
bool isGhostAimConsistent({
  required math.Point<double> cue,
  required math.Point<double> object,
  required TablePocket pocket,
  required ContactFraction fraction,
  BallSizes sizes = BallSizes.standard,
}) =>
    ghostAimDeviation(
      cue: cue,
      object: object,
      pocket: pocket,
      fraction: fraction,
      sizes: sizes,
    ) <=
    ghostAimTolerance(sizes: sizes);
