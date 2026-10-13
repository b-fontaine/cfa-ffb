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
