import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/tip_point.dart';

/// Hauteur du point d'impact sur la blanche vue de côté, de -1 (bas) à 1
/// (haut), en part du rayon : le haut et le bas donnent ±1, les diagonales la
/// part verticale d'une direction unitaire, le centre et les côtés 0 (un
/// impact à gauche ou à droite ne se voit pas de côté).
double tipHeightFactor(TipPoint tip) {
  final diagonal = math.sqrt(0.5);
  return switch (tip) {
    TipPoint.top => 1,
    TipPoint.topLeft || TipPoint.topRight => diagonal,
    TipPoint.center || TipPoint.left || TipPoint.right => 0,
    TipPoint.bottomLeft || TipPoint.bottomRight => -diagonal,
    TipPoint.bottom => -1,
  };
}

/// Inclinaison de la queue (radians, talon relevé) pour une hauteur de
/// talon. Valeurs schématiques `[Prop]` : bas = presque à plat, moyen = 10°,
/// haut = 25°.
double cueElevation(CueHeight height) => switch (height) {
  CueHeight.low => 0,
  CueHeight.level => 10 * math.pi / 180,
  CueHeight.high => 25 * math.pi / 180,
};

/// Position du procédé sur la blanche en part de son rayon `[Prop]` : pour un
/// point de la périphérie (haut, bas, côtés), le procédé est à mi-rayon du
/// centre, sa forme (8,5 mm) tenant dans la blanche.
const double tipOffsetShare = 0.5;

/// Contact entre la blanche et une bille de but posées sur le tapis, vue de
/// côté : `tilt` est l'inclinaison de la ligne des centres (radians) et
/// `height` la hauteur du contact **au-dessus de l'équateur de la blanche**,
/// dans l'unité des rayons.
///
/// Les centres sont à `r_c` et `r_o` du tapis : leur écart de hauteur est
/// `r_o - r_c` et la distance entre centres `s = r_c + r_o`, d'où
/// `sin φ = (r_o - r_c) / s` et `h = r_c · sin φ` (fiche n° 4 `[S]` :
/// « légèrement au-dessus de l'axe horizontal de la bille blanche »).
({double tilt, double height}) contactHeight({
  required double cueRadius,
  required double objectRadius,
}) {
  final sin = (objectRadius - cueRadius) / (cueRadius + objectRadius);
  return (tilt: math.asin(sin), height: cueRadius * sin);
}

/// Rayon d'une bille de but dont l'écart avec la blanche est multiplié par
/// [factor] (exagération pour rendre le contact visible, à signaler dans la
/// légende) : `r_c + factor · (r_o - r_c)`.
double exaggeratedObjectRadius({
  required double cueRadius,
  required double objectRadius,
  required double factor,
}) => cueRadius + factor * (objectRadius - cueRadius);
