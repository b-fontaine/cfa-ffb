import 'dart:math' as math;

/// Cotes du matériel de Blackball : **seule** déclaration de cote du dépôt.
///
/// Les valeurs en millimètres viennent de `[FFB]` (code d'arbitrage Blackball,
/// page discipline), recoupées par `[Web]` ; voir
/// `docs/knowledge/02-techniques/06-dimensions-du-materiel.md` pour le rang, la
/// confiance et les désaccords tranchés. Les valeurs en cases en sont
/// **dérivées** : jamais retapées.
///
/// Au Blackball la blanche (48,0 mm) est plus petite que les billes de but
/// (50,8 mm) `[S]` : aucun calcul ni dessin ne doit utiliser un rayon unique.
abstract final class BlackballDimensions {
  // --- Millimètres [FFB] ---

  /// Diamètre d'une bille de but (7 rouges, 7 jaunes, noire n° 8).
  static const double objectBallDiameterMm = 50.8;

  /// Diamètre de la blanche. La variante WEPF (47,6 mm) est testable par
  /// [BallSizes], non retenue.
  static const double cueBallDiameterMm = 48;

  /// Longueur de la surface de jeu, entre bandes.
  static const double playAreaLengthMm = 1850;

  /// Largeur de la surface de jeu, entre bandes.
  static const double playAreaWidthMm = 925;

  /// Entrée de poche (six poches identiques).
  static const double pocketOpeningMm = 76.2;

  /// Diamètre du procédé (8 à 9 mm).
  static const double tipDiameterMm = 8.5;

  /// Ligne de départ : fraction de la longueur bande à bande `[FFB]`.
  static const double headStringFraction = 0.2;

  /// Hauteur de bande.
  static const double cushionHeightMm = 36;

  /// Longueur d'une queue : 57 in ≈ 1450 mm, valeur commerciale `[Web]`, non
  /// spécifiée par la FFB (confiance basse) ; sert aux proportions du dessin,
  /// jamais affichée comme une cote.
  static const double cueLengthMm = 1450;

  /// Diamètre du talon d'une queue, ≈ 30 mm `[Prop]` (proportions du dessin).
  static const double cueButtDiameterMm = 30;

  // --- Repère des schémas : une case = un quart de la largeur ---

  /// Côté d'une case, en millimètres (231,25).
  static const double cellMm = playAreaWidthMm / 4;

  /// Nombre de cases dans la longueur.
  static const double columns = 8;

  /// Nombre de cases dans la largeur.
  static const double rows = 4;

  // --- En cases (dérivés) ---

  /// Rayon d'une bille de but, en cases (0,109838).
  static const double objectBallRadius = objectBallDiameterMm / 2 / cellMm;

  /// Rayon de la blanche, en cases (0,103784).
  static const double cueBallRadius = cueBallDiameterMm / 2 / cellMm;

  /// Distance entre le centre de la blanche et celui d'une bille de but au
  /// contact, en cases : `s = r_c + r_o` (0,213622).
  static const double ghostDistance = objectBallRadius + cueBallRadius;

  /// Ouverture d'une poche, en cases (0,329514).
  static const double pocketOpening = pocketOpeningMm / cellMm;

  /// Ligne de départ selon la règle `[FFB]` : 1/5 de la longueur (1,6 case).
  static const double headStringFromRule = columns * headStringFraction;

  /// Ligne de départ dessinée par le dépôt `[Prop]` (arbitrage ouvert : doc de
  /// dimensions § 4).
  static const double headStringDrawn = 2;

  /// Longueur de la queue, en cases (6,27).
  static const double cueLength = cueLengthMm / cellMm;

  /// Épaisseur du talon de la queue, en cases (0,1297).
  static const double cueButtThickness = cueButtDiameterMm / cellMm;

  /// Rapport procédé / talon (0,283) : finesse de la pointe d'une queue.
  static const double cueTipToButt = tipDiameterMm / cueButtDiameterMm;

  /// Rayon du procédé en rayons de blanche (0,177).
  static const double tipRadiusOnCueBall = tipDiameterMm / cueBallDiameterMm;

  // --- Hauteur du contact blanche / bille de but (vue de côté) ---

  /// Écart de hauteur des centres : une bille de but est plus haute que la
  /// blanche, toutes deux posées sur le tapis (1,4 mm).
  static const double centerHeightGapMm =
      (objectBallDiameterMm - cueBallDiameterMm) / 2;

  /// Écart de hauteur des centres, en cases (0,006054).
  static const double centerHeightGap = centerHeightGapMm / cellMm;

  /// Inclinaison de la ligne des centres au contact, en degrés (1,62).
  static final double contactTiltDegrees =
      math.asin(
        centerHeightGapMm / (cueBallDiameterMm / 2 + objectBallDiameterMm / 2),
      ) *
      180 /
      math.pi;

  /// Hauteur du point de contact **au-dessus** de l'équateur de la blanche, en
  /// millimètres (0,68) : « légèrement au-dessus de l'axe horizontal de la
  /// bille blanche » `[S]` (fiche n° 4).
  static const double contactHeightAboveCueEquatorMm =
      cueBallDiameterMm /
      2 *
      centerHeightGapMm /
      (cueBallDiameterMm / 2 + objectBallDiameterMm / 2);
}

/// Tailles de billes pour un calcul de géométrie : la blanche et les billes de
/// but ont des diamètres différents.
///
/// Les fonctions de géométrie prennent un [BallSizes] facultatif (défaut
/// [standard]) : on teste ainsi la variante WEPF (47,6 mm) et le cas « billes
/// égales » (régression) sans dupliquer de constante.
class BallSizes {
  const BallSizes({
    this.cueDiameterMm = BlackballDimensions.cueBallDiameterMm,
    this.objectDiameterMm = BlackballDimensions.objectBallDiameterMm,
  });

  /// Cotes retenues (48,0 mm et 50,8 mm).
  static const BallSizes standard = BallSizes();

  /// Diamètre de la blanche, en millimètres.
  final double cueDiameterMm;

  /// Diamètre d'une bille de but, en millimètres.
  final double objectDiameterMm;

  /// Rayon de la blanche, en cases.
  double get cueRadius => cueDiameterMm / 2 / BlackballDimensions.cellMm;

  /// Rayon d'une bille de but, en cases.
  double get objectRadius => objectDiameterMm / 2 / BlackballDimensions.cellMm;

  /// Distance entre centres au contact blanche / bille de but, en cases.
  double get ghostDistance => cueRadius + objectRadius;

  /// Rapport blanche / bille de but (rayon ou diamètre).
  double get ratio => cueDiameterMm / objectDiameterMm;

  /// Rayon en cases de la blanche ([isCueBall]) ou d'une bille de but.
  double radiusOf({required bool isCueBall}) =>
      isCueBall ? cueRadius : objectRadius;
}
