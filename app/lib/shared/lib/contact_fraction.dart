import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';

/// Quantité de bille : part de la bille de but recouverte par la blanche.
///
/// Dart pur : source unique, partagée par le petit schéma de quantité de bille,
/// le modèle de schéma d'exercice et les illustrations des séances.
///
/// Chaque quantité se définit par [aimOffset], la distance `d` entre la ligne
/// de visée (trajectoire du centre de la blanche) et le centre de la bille de
/// but. Les rayons de la blanche et de la bille de but étant différents, `d`
/// suit les définitions `[S]` (docs/knowledge/02-techniques/
/// 06-dimensions-du-materiel.md § 3.3) : le demi-bille et le trois-quarts se
/// repèrent sur la bille de but, seul le quart de bille se mesure « par rapport
/// à la blanche » (fiche n° 7).
enum ContactFraction {
  /// Visée au centre de la bille de but.
  full,

  /// À égale distance du centre et de la tangente : `r_o / 2`.
  threeQuarter,

  /// Le centre de la blanche passe par la tangente : `r_o`.
  half,

  /// Un demi-rayon de blanche au-delà de la tangente : `r_o + r_c / 2`.
  quarter,

  /// Contact rasant `[Prop]` : `0,95 · s`.
  thin;

  /// Part du contact rasant `s` retenue pour la finesse `[Prop]`.
  static const double thinShareOfContact = 0.95;

  /// Distance, en cases, entre la ligne de visée et le centre de la bille de
  /// but pour des billes de tailles [sizes].
  double aimOffset([BallSizes sizes = BallSizes.standard]) => switch (this) {
    ContactFraction.full => 0,
    ContactFraction.threeQuarter => sizes.objectRadius / 2,
    ContactFraction.half => sizes.objectRadius,
    ContactFraction.quarter => sizes.objectRadius + sizes.cueRadius / 2,
    ContactFraction.thin => thinShareOfContact * sizes.ghostDistance,
  };

  /// Angle de coupe nominal (radians) : `asin(d / s)`, direction prise par la
  /// bille de but.
  double nominalCutAngle([BallSizes sizes = BallSizes.standard]) =>
      math.asin(aimOffset(sizes) / sizes.ghostDistance);
}
