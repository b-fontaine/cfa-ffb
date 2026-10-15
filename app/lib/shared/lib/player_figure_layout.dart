import 'dart:math' as math;

/// Parties du joueur présentées par l'illustration `player_figure`, dans
/// l'ordre numérique de la légende (fiche technique n° 1, étape 2).
enum PlayerMark {
  /// Pieds ni trop serrés ni trop espacés, pied droit sous la main arrière.
  feet,

  /// Bassin pivoté, jambe droite tendue, jambe gauche fléchie.
  legsAndHips,

  /// Tête dans l'axe de la queue, œil directeur au-dessus.
  head,

  /// Avant-bras arrière à la verticale, coude à l'aplomb de la main.
  backForearm,

  /// Main de chevalet sur le cadre ou sur le tapis.
  bridgeHand,

  /// Queue dans l'axe de la visée, vers le centre de la blanche.
  cue;

  /// Numéro de la pastille (1 à 6).
  int get number => index + 1;
}

/// Vue présentée : de profil, de dessus, ou les deux.
enum PlayerView { side, top, both }

/// Latéralité du joueur dessiné : la pose est calculée pour un droitier et
/// **mise en miroir** pour un gaucher (fiche n° 1 : « tout se lit à
/// l'envers »).
enum Handedness { right, left }

/// Place de la tête par rapport à la queue, vue de dessus (fiche n° 1,
/// étape 2 : selon l'œil directeur).
enum HeadCase { rightEyeOverCue, cueBetweenEyes, leftEyeOverCue }

/// Œil directeur du joueur droitier.
enum LeadEye { left, right }

/// Appui de la main de chevalet.
enum CueBridge {
  /// Chevalet sur cadre : la main s'appuie sur le rail de la table.
  frame,

  /// Chevalet sur surface : la main est posée sur le tapis.
  surface,
}

/// Joueur de profil, droitier, qui regarde vers la droite.
///
/// Unité : la taille du joueur `H` (= 1) ; `x` vers la droite (vers la
/// blanche), `y` **vers le haut**, origine au sol. Proportions `[Prop]` : le
/// plateau est à 0,48 H (820 à 850 mm pour une table de 1,75 m), la queue
/// mesure 0,83 H (≈ 1450 mm) et son talon est relevé de 10° sur la surface,
/// de 14° sur le cadre (jamais une queue strictement horizontale : la fiche
/// n° 1 ne dit pas « horizontale »). Les billes sont **agrandies** (rayon
/// 0,028 H au lieu de 0,014 H).
///
/// Le joueur est **penché** : le buste monte de moins de 0,15 H des hanches
/// aux épaules et le menton reste à quelques centimètres au-dessus de la
/// queue (« tête au-dessus de la queue » ; un peu relevée sur le cadre, « au
/// plus près de la queue » sur la surface, fiche n° 1). Le corps est placé
/// par rapport à la main arrière : le pied droit sous elle, les hanches
/// juste derrière, le pied gauche en avant. Sur le cadre, la blanche est
/// près de la bande (c'est l'usage de ce chevalet) ; la main de chevalet est
/// posée sous la queue, sa position se déduit de la droite de la queue (la
/// queue repose sur le haut de la main).
class SidePose {
  const SidePose._({
    required this.bridge,
    required this.elevation,
    required this.tip,
    required this.butt,
    required this.ballCenter,
    required this.backHand,
    required this.elbow,
    required this.shoulder,
    required this.leftShoulder,
    required this.hip,
    required this.head,
    required this.bridgeHand,
    required this.rightFoot,
    required this.leftFoot,
    required this.leftKnee,
  });

  /// Pose pour un appui de [bridge].
  factory SidePose.of(CueBridge bridge) {
    final elevation = elevationOf(bridge);
    final ballCenter = math.Point<double>(
      ballXOf(bridge),
      tableTop + drawnBallRadius,
    );
    // La pointe touche la blanche : à un rayon du centre, sur la droite de la
    // queue (qui passe par le centre).
    final tip = math.Point<double>(
      ballCenter.x - drawnBallRadius * math.cos(elevation),
      ballCenter.y + drawnBallRadius * math.sin(elevation),
    );
    final butt = math.Point<double>(
      tip.x - cueLength * math.cos(elevation),
      tip.y + cueLength * math.sin(elevation),
    );
    const gripDistance = 0.66;
    final backHand = math.Point<double>(
      tip.x - gripDistance * math.cos(elevation),
      tip.y + gripDistance * math.sin(elevation),
    );
    final handBottom = bridge == CueBridge.frame ? railTop : tableTop;
    final handCentreY = handBottom + handRadius;
    // La queue passe au sommet de la main : y_queue(x) = y_main + r.
    final bridgeX =
        tip.x - (handCentreY + handRadius - tip.y) / math.tan(elevation);
    // Le corps se place par rapport à la main arrière.
    final x0 = backHand.x;
    final headX = tip.x - headBack;
    final cueAtHead = tip.y + (tip.x - headX) * math.tan(elevation);
    return SidePose._(
      bridge: bridge,
      elevation: elevation,
      tip: tip,
      butt: butt,
      ballCenter: ballCenter,
      backHand: backHand,
      elbow: math.Point<double>(backHand.x, backHand.y + forearmLength),
      shoulder: math.Point<double>(x0 + 0.16, 0.68),
      leftShoulder: math.Point<double>(x0 + 0.20, 0.67),
      hip: math.Point<double>(x0 - 0.06, 0.56),
      head: math.Point<double>(
        headX,
        cueAtHead + chinClearanceOf(bridge) + headRadius,
      ),
      bridgeHand: math.Point<double>(bridgeX, handCentreY),
      rightFoot: math.Point<double>(x0, footHeight),
      leftFoot: math.Point<double>(x0 + 0.24, footHeight),
      leftKnee: math.Point<double>(x0 + 0.20, 0.30),
    );
  }

  /// Inclinaison de la queue (talon relevé) selon l'appui : 10° sur la
  /// surface, 14° sur le cadre (la main y est plus haute, la queue descend
  /// vers la blanche).
  static double elevationOf(CueBridge bridge) => switch (bridge) {
    CueBridge.surface => _elevation,
    CueBridge.frame => 14 * math.pi / 180,
  };

  /// Abscisse de la blanche : près de la bande sur le cadre (0,10 H du bord
  /// du rail, qui s'arrête à 0,95), loin d'elle sur la surface.
  static double ballXOf(CueBridge bridge) => switch (bridge) {
    CueBridge.surface => 1.22,
    CueBridge.frame => 1.05,
  };

  /// Espace entre le bas de la tête (menton) et l'axe de la queue : au plus
  /// près sur la surface, un peu relevée sur le cadre (fiche n° 1).
  static double chinClearanceOf(CueBridge bridge) => switch (bridge) {
    CueBridge.surface => 0.035,
    CueBridge.frame => 0.06,
  };

  /// Recul de la tête par rapport à la pointe de la queue.
  static const double headBack = 0.30;

  /// Hauteur du plateau (tapis) : 0,48 H.
  static const double tableTop = 0.48;

  /// Hauteur du haut du rail sur lequel s'appuie un chevalet sur cadre
  /// (bande d'environ 36 mm au-dessus du tapis).
  static const double railTop = 0.50;

  /// Rayon de la blanche dessinée (agrandie).
  static const double drawnBallRadius = 0.028;

  /// Rayon de la main de chevalet.
  static const double handRadius = 0.025;

  /// Rayon de la tête.
  static const double headRadius = 0.065;

  /// Longueur de la queue : 0,83 H.
  static const double cueLength = 0.83;

  /// Longueur de l'avant-bras arrière.
  static const double forearmLength = 0.15;

  /// Hauteur du pied (centre de l'ovale) au-dessus du sol.
  static const double footHeight = 0.02;

  /// Cadre du dessin : `left`, `right`, `bottom`, `top` en unités de H.
  static const ({double left, double right, double bottom, double top}) frame =
      (left: 0.20, right: 1.40, bottom: -0.04, top: 0.90);

  /// Rapport largeur / hauteur du cadre (1,25).
  static const double aspect = 1.2 / 0.94;

  /// Talon relevé de 10°, valeur de `cueElevation(CueHeight.level)`.
  static const double _elevation = 10 * math.pi / 180;

  final CueBridge bridge;

  /// Inclinaison de la queue (radians, talon relevé).
  final double elevation;

  /// Pointe de la queue, au contact de la blanche.
  final math.Point<double> tip;

  /// Talon de la queue.
  final math.Point<double> butt;
  final math.Point<double> ballCenter;

  /// Main arrière, qui tient la queue.
  final math.Point<double> backHand;

  /// Coude arrière, à l'aplomb de la main.
  final math.Point<double> elbow;
  final math.Point<double> shoulder;
  final math.Point<double> leftShoulder;
  final math.Point<double> hip;

  /// Centre de la tête.
  final math.Point<double> head;

  /// Centre de la main de chevalet.
  final math.Point<double> bridgeHand;
  final math.Point<double> rightFoot;
  final math.Point<double> leftFoot;
  final math.Point<double> leftKnee;

  /// Hauteur de l'axe de la queue à l'abscisse [x].
  double cueHeightAt(double x) => tip.y + (tip.x - x) * math.tan(elevation);

  /// Centre de la pastille de [mark], dans le cadre.
  math.Point<double> badgeOf(PlayerMark mark) => switch (mark) {
    PlayerMark.feet => const math.Point(0.34, 0.12),
    PlayerMark.legsAndHips => const math.Point(0.28, 0.42),
    PlayerMark.head => const math.Point(1, 0.84),
    PlayerMark.backForearm => const math.Point(0.36, 0.84),
    PlayerMark.bridgeHand => const math.Point(1.12, 0.30),
    PlayerMark.cue => const math.Point(1.30, 0.72),
  };

  /// Point du dessin que désigne le trait de renvoi de [mark].
  math.Point<double> targetOf(PlayerMark mark) => switch (mark) {
    PlayerMark.feet => rightFoot,
    PlayerMark.legsAndHips => hip,
    PlayerMark.head => head,
    PlayerMark.backForearm => math.Point(
      backHand.x,
      (backHand.y + elbow.y) / 2,
    ),
    PlayerMark.bridgeHand => bridgeHand,
    PlayerMark.cue => math.Point(
      (tip.x + backHand.x) / 2 + 0.2,
      cueHeightAt((tip.x + backHand.x) / 2 + 0.2),
    ),
  };
}

/// Joueur vu de dessus (positions en part de la largeur `x` et de la hauteur
/// `y`, `y` vers le bas). Le joueur regarde vers la droite, la queue suit
/// l'axe `y = 0,5` : la droite du joueur est donc **en bas** du dessin.
abstract final class TopPose {
  /// Rapport largeur / hauteur du schéma.
  static const double aspect = 1.6;

  /// Talon de la queue.
  static const butt = math.Point<double>(0.06, 0.5);

  /// Centre de la blanche.
  static const ball = math.Point<double>(0.94, 0.5);

  /// Main arrière, sur l'axe, à l'aplomb du pied droit.
  static const backHand = math.Point<double>(0.34, 0.5);

  /// Tête (sans décalage), sur l'axe de la queue.
  static const head = math.Point<double>(0.6, 0.5);

  /// Main de chevalet, sur l'axe devant la tête.
  static const bridge = math.Point<double>(0.8, 0.5);

  /// Pied droit, sous la main droite qui tient la queue.
  static const rightFoot = math.Point<double>(0.34, 0.86);

  /// Pied gauche, devant et à gauche de l'axe.
  static const leftFoot = math.Point<double>(0.5, 0.16);

  /// Hanches (bassin légèrement pivoté).
  static const rightHip = math.Point<double>(0.36, 0.64);
  static const leftHip = math.Point<double>(0.44, 0.40);

  /// Épaules.
  static const rightShoulder = math.Point<double>(0.50, 0.68);
  static const leftShoulder = math.Point<double>(0.58, 0.32);

  /// Écart des yeux à l'axe de la tête, en part de la hauteur.
  static const double eyeOffset = 0.07;

  /// Avancée des yeux sur le centre de la tête, en part de la largeur.
  static const double eyeAhead = 0.02;

  /// Étendue en x (part de la largeur) du rail de la table : la main de
  /// chevalet est **sur** le rail (chevalet sur cadre) ou sur le tapis, juste
  /// après le rail (chevalet sur surface).
  static (double, double) railSpan(CueBridge bridge) => switch (bridge) {
    CueBridge.frame => (0.74, 0.86),
    CueBridge.surface => (0.70, 0.76),
  };

  /// Marques visibles de dessus : l'avant-bras se lit de profil.
  static const List<PlayerMark> visibleMarks = [
    PlayerMark.feet,
    PlayerMark.legsAndHips,
    PlayerMark.head,
    PlayerMark.bridgeHand,
    PlayerMark.cue,
  ];

  /// Centre de la tête : décalé pour que l'œil du cas [headCase] soit sur
  /// l'axe de la queue, au milieu sans cas.
  static math.Point<double> headCentre([HeadCase? headCase]) =>
      switch (headCase) {
        // L'œil droit est sous le centre : la tête monte d'un écart d'œil.
        HeadCase.rightEyeOverCue => const math.Point(0.6, 0.5 - eyeOffset),
        HeadCase.leftEyeOverCue => const math.Point(0.6, 0.5 + eyeOffset),
        HeadCase.cueBetweenEyes || null => head,
      };

  /// Position d'un œil : à l'avant de la tête, de part et d'autre de son axe.
  static math.Point<double> eye(LeadEye which, [HeadCase? headCase]) {
    final centre = headCentre(headCase);
    return math.Point(
      centre.x + eyeAhead,
      centre.y + (which == LeadEye.right ? eyeOffset : -eyeOffset),
    );
  }

  /// Centre de la pastille de [mark].
  static math.Point<double> badgeOf(PlayerMark mark) => switch (mark) {
    PlayerMark.feet => const math.Point(0.18, 0.86),
    PlayerMark.legsAndHips => const math.Point(0.22, 0.66),
    PlayerMark.head => const math.Point(0.72, 0.14),
    PlayerMark.backForearm => const math.Point(0.34, 0.30),
    PlayerMark.bridgeHand => const math.Point(0.84, 0.82),
    PlayerMark.cue => const math.Point(0.14, 0.30),
  };

  /// Point que désigne le trait de renvoi de [mark].
  static math.Point<double> targetOf(PlayerMark mark, [HeadCase? headCase]) =>
      switch (mark) {
        PlayerMark.feet => rightFoot,
        PlayerMark.legsAndHips => rightHip,
        PlayerMark.head => headCentre(headCase),
        PlayerMark.backForearm => backHand,
        PlayerMark.bridgeHand => bridge,
        PlayerMark.cue => const math.Point(0.15, 0.5),
      };
}
