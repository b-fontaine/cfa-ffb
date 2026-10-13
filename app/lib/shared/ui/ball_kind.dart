import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';

/// Les quatre groupes de billes du Blackball.
///
/// Dart pur : source unique de la couleur d'une bille, partagée par la
/// pastille, la bille peinte et le modèle de schéma d'exercice.
enum BallKind { red, yellow, black, white }

/// Taille d'une bille selon son groupe : la blanche est plus petite que les
/// billes de but `[S]` (cotes : `BlackballDimensions`).
extension BallKindSize on BallKind {
  /// Vrai pour la blanche.
  bool get isCueBall => this == BallKind.white;

  /// Rayon en cases du repère des schémas (blanche 0,1038, bille de but
  /// 0,1098).
  double get radius => isCueBall
      ? BlackballDimensions.cueBallRadius
      : BlackballDimensions.objectBallRadius;
}
