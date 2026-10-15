import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';

/// Exercice réel recopié d'une transcription YAML de
/// `docs/knowledge/03-exercices/diagrammes/`.
class DiagramExample {
  const DiagramExample({
    required this.name,
    required this.source,
    required this.description,
    required this.spec,
  });

  final String name;

  /// Fichier et identifiant de la transcription.
  final String source;

  /// Énoncé de la fiche (champ `caption`), repris comme description parlée.
  final String description;

  final TableDiagramSpec spec;
}

/// `entrainement/p03.yaml`, `entrainement-p03-e1`.
const fullBall = DiagramExample(
  name: 'Bille pleine',
  source: 'entrainement/p03.yaml#entrainement-p03-e1',
  description:
      'Empocher huit billes en quantité de bille pleine, avec un chevalet '
      'sur cadre.',
  spec: TableDiagramSpec(
    id: 'entrainement-p03-e1',
    balls: [
      DiagramBall(
        id: 'y1',
        color: BallKind.yellow,
        at: DiagramPoint(1.18, 2.07),
        label: 'x4',
      ),
      DiagramBall(
        id: 'y2',
        color: BallKind.yellow,
        at: DiagramPoint(2.83, 2.08),
        label: 'x4',
      ),
      DiagramBall(
        id: 'w',
        color: BallKind.white,
        at: DiagramPoint(1.99, 3.51),
        role: DiagramBallRole.cue,
      ),
    ],
    ghosts: [
      DiagramGhost(
        id: 'g1',
        at: DiagramPoint(1.29, 2.28),
        role: DiagramGhostRole.impact,
        forBallId: 'w',
      ),
      DiagramGhost(
        id: 'g2',
        at: DiagramPoint(2.71, 2.29),
        role: DiagramGhostRole.impact,
        forBallId: 'w',
      ),
    ],
    arrows: [
      DiagramArrow(
        id: 'a1',
        kind: DiagramArrowKind.cue,
        ballId: 'w',
        path: [DiagramPoint(1.99, 3.51), DiagramPoint(1.29, 2.28)],
      ),
      DiagramArrow(
        id: 'a2',
        kind: DiagramArrowKind.object,
        ballId: 'y1',
        path: [DiagramPoint(1.18, 2.07), DiagramPoint(0, 0)],
        pocket: DiagramPocket.tl,
      ),
      DiagramArrow(
        id: 'a3',
        kind: DiagramArrowKind.cue,
        ballId: 'w',
        path: [DiagramPoint(1.99, 3.51), DiagramPoint(2.71, 2.29)],
      ),
      DiagramArrow(
        id: 'a4',
        kind: DiagramArrowKind.object,
        ballId: 'y2',
        path: [DiagramPoint(2.83, 2.08), DiagramPoint(4, 0)],
        pocket: DiagramPocket.tm,
      ),
    ],
    steps: [
      DiagramStep(
        cueId: 'w',
        hitId: 'y1',
        contact: ContactFraction.full,
        pocket: DiagramPocket.tl,
        repeat: 4,
      ),
      DiagramStep(
        cueId: 'w',
        hitId: 'y2',
        contact: ContactFraction.full,
        pocket: DiagramPocket.tm,
        repeat: 4,
      ),
    ],
  ),
);

/// `entrainement/p06.yaml`, `entrainement-p06-e3`.
const halfBall = DiagramExample(
  name: 'Demi-bille',
  source: 'entrainement/p06.yaml#entrainement-p06-e3',
  description:
      'Empocher huit billes en quantité demi-bille avec un chevalet sur '
      'cadre.',
  spec: TableDiagramSpec(
    id: 'entrainement-p06-e3',
    balls: [
      DiagramBall(
        id: 'y1',
        color: BallKind.yellow,
        at: DiagramPoint(1, 1.05),
        label: 'x4',
      ),
      DiagramBall(
        id: 'y2',
        color: BallKind.yellow,
        at: DiagramPoint(3, 1.05),
        label: 'x4',
      ),
      DiagramBall(
        id: 'w',
        color: BallKind.white,
        at: DiagramPoint(2, 3.65),
        role: DiagramBallRole.cue,
      ),
    ],
    ghosts: [
      DiagramGhost(
        id: 'g1',
        at: DiagramPoint(1.15, 1.2),
        role: DiagramGhostRole.impact,
        forBallId: 'w',
      ),
      DiagramGhost(
        id: 'g2',
        at: DiagramPoint(2.8, 1.2),
        role: DiagramGhostRole.impact,
        forBallId: 'w',
      ),
    ],
    arrows: [
      DiagramArrow(
        id: 'a1',
        kind: DiagramArrowKind.cue,
        ballId: 'w',
        path: [DiagramPoint(2, 3.65), DiagramPoint(1.15, 1.2)],
      ),
      DiagramArrow(
        id: 'a2',
        kind: DiagramArrowKind.object,
        ballId: 'y1',
        path: [DiagramPoint(1, 1.05), DiagramPoint(0, 0)],
        pocket: DiagramPocket.tl,
      ),
      DiagramArrow(
        id: 'a3',
        kind: DiagramArrowKind.cue,
        ballId: 'w',
        path: [DiagramPoint(2, 3.65), DiagramPoint(2.8, 1.2)],
      ),
      DiagramArrow(
        id: 'a4',
        kind: DiagramArrowKind.object,
        ballId: 'y2',
        path: [DiagramPoint(3, 1.05), DiagramPoint(4, 0)],
        pocket: DiagramPocket.tm,
      ),
    ],
    steps: [
      DiagramStep(
        cueId: 'w',
        hitId: 'y1',
        contact: ContactFraction.half,
        pocket: DiagramPocket.tl,
        repeat: 4,
      ),
      DiagramStep(
        cueId: 'w',
        hitId: 'y2',
        contact: ContactFraction.half,
        pocket: DiagramPocket.tm,
        repeat: 4,
      ),
    ],
  ),
);

/// `jeux/p03.yaml`, `jeux-p03-g1` (jeu de la puissance, sans tir à dérouler).
const powerGame = DiagramExample(
  name: 'Jeu de la puissance',
  source: 'jeux/p03.yaml#jeux-p03-g1',
  description:
      'La puissance : viser et placer la bille blanche dans le camp adverse, '
      'matérialisé par une zone grise entourée de quatre billes.',
  spec: TableDiagramSpec(
    id: 'jeux-p03-g1',
    balls: [
      DiagramBall(id: 'r1', color: BallKind.red, at: DiagramPoint(0.17, 1.51)),
      DiagramBall(id: 'r2', color: BallKind.red, at: DiagramPoint(0.99, 1.51)),
      DiagramBall(id: 'r3', color: BallKind.red, at: DiagramPoint(0.17, 2.64)),
      DiagramBall(id: 'r4', color: BallKind.red, at: DiagramPoint(0.99, 2.64)),
      DiagramBall(
        id: 'y1',
        color: BallKind.yellow,
        at: DiagramPoint(7.06, 1.51),
      ),
      DiagramBall(
        id: 'y2',
        color: BallKind.yellow,
        at: DiagramPoint(7.85, 1.51),
      ),
      DiagramBall(
        id: 'y3',
        color: BallKind.yellow,
        at: DiagramPoint(7.06, 2.64),
      ),
      DiagramBall(
        id: 'y4',
        color: BallKind.yellow,
        at: DiagramPoint(7.85, 2.64),
      ),
    ],
    ghosts: [
      DiagramGhost(
        id: 'g1',
        at: DiagramPoint(1.09, 2.07),
        role: DiagramGhostRole.cueStart,
      ),
    ],
    arrows: [
      DiagramArrow(
        id: 'a1',
        kind: DiagramArrowKind.indication,
        path: [DiagramPoint(1.09, 2.07), DiagramPoint(6.8, 2.07)],
      ),
    ],
    zones: [
      DiagramZone(
        id: 'z1',
        from: DiagramPoint(0.09, 1.51),
        to: DiagramPoint(0.99, 2.64),
      ),
      DiagramZone(
        id: 'z2',
        from: DiagramPoint(7.05, 1.51),
        to: DiagramPoint(7.94, 2.64),
      ),
    ],
  ),
);

/// `entrainement/p16.yaml`, `entrainement-p16-e3` (deux bandes avant la bille).
const twoCushions = DiagramExample(
  name: 'Deux bandes',
  source: 'entrainement/p16.yaml#entrainement-p16-e3',
  description: 'Jouer sur deux bandes avant de toucher une bille.',
  spec: TableDiagramSpec(
    id: 'entrainement-p16-e3',
    balls: [
      DiagramBall(
        id: 'b8',
        color: BallKind.black,
        at: DiagramPoint(3.09, 2.38),
        label: '8',
      ),
      DiagramBall(id: 'r1', color: BallKind.red, at: DiagramPoint(3.5, 3.09)),
      DiagramBall(
        id: 'y1',
        color: BallKind.yellow,
        at: DiagramPoint(6.99, 3.83),
        label: '1',
      ),
      DiagramBall(
        id: 'y2',
        color: BallKind.yellow,
        at: DiagramPoint(5.84, 3.83),
        label: '2',
      ),
      DiagramBall(
        id: 'y3',
        color: BallKind.yellow,
        at: DiagramPoint(4.75, 3.83),
        label: '3',
      ),
      DiagramBall(
        id: 'w',
        color: BallKind.white,
        at: DiagramPoint(2.99, 2.98),
        role: DiagramBallRole.cue,
      ),
    ],
    ghosts: [
      DiagramGhost(
        id: 'g-start',
        at: DiagramPoint(2.99, 2.98),
        role: DiagramGhostRole.cueStart,
      ),
    ],
    arrows: [
      DiagramArrow(
        id: 'c-y1',
        kind: DiagramArrowKind.cue,
        ballId: 'w',
        path: [
          DiagramPoint(2.99, 2.98),
          DiagramPoint(5.5, 0.17),
          DiagramPoint(7.87, 2.79),
          DiagramPoint(7.17, 3.62),
        ],
        bounces: [DiagramBand.top, DiagramBand.right],
      ),
      DiagramArrow(
        id: 'c-y2',
        kind: DiagramArrowKind.cue,
        ballId: 'w',
        path: [
          DiagramPoint(2.99, 2.98),
          DiagramPoint(6, 0.15),
          DiagramPoint(7.87, 1.89),
          DiagramPoint(6, 3.62),
        ],
        bounces: [DiagramBand.top, DiagramBand.right],
      ),
    ],
    steps: [
      DiagramStep(cueId: 'w', hitId: 'y1'),
      DiagramStep(cueId: 'w', hitId: 'y2'),
    ],
  ),
);

/// `entrainement/p05.yaml`, `entrainement-p05-e1` : six repères numérotés de
/// la blanche, deux alignements ; sert à vérifier que les numéros se posent
/// à côté des trajectoires et non dessus.
const sixPositions = DiagramExample(
  name: 'Six repères (demi-bille)',
  source: 'entrainement/p05.yaml#entrainement-p05-e1',
  description:
      'Empocher six billes en quantité demi-bille selon des distances '
      'différentes.',
  spec: TableDiagramSpec(
    id: 'entrainement-p05-e1',
    balls: [
      DiagramBall(id: 'r1', color: BallKind.red, at: DiagramPoint(4, 0.98)),
      DiagramBall(
        id: 'w',
        color: BallKind.white,
        at: DiagramPoint(3.51, 1.97),
        role: DiagramBallRole.cue,
        label: '1',
      ),
    ],
    ghosts: [
      DiagramGhost(
        id: 'g2',
        at: DiagramPoint(4.47, 1.97),
        role: DiagramGhostRole.cueStart,
        label: '2',
        forBallId: 'w',
      ),
      DiagramGhost(
        id: 'g3',
        at: DiagramPoint(2.98, 2.79),
        role: DiagramGhostRole.cueStart,
        label: '3',
        forBallId: 'w',
      ),
      DiagramGhost(
        id: 'g4',
        at: DiagramPoint(4.99, 2.79),
        role: DiagramGhostRole.cueStart,
        label: '4',
        forBallId: 'w',
      ),
      DiagramGhost(
        id: 'g5',
        at: DiagramPoint(2.43, 3.64),
        role: DiagramGhostRole.cueStart,
        label: '5',
        forBallId: 'w',
      ),
      DiagramGhost(
        id: 'g6',
        at: DiagramPoint(5.57, 3.64),
        role: DiagramGhostRole.cueStart,
        label: '6',
        forBallId: 'w',
      ),
      DiagramGhost(
        id: 'gi',
        at: DiagramPoint(4, 1.25),
        role: DiagramGhostRole.impact,
        forBallId: 'w',
      ),
    ],
    arrows: [
      DiagramArrow(
        id: 'a1',
        kind: DiagramArrowKind.object,
        path: [DiagramPoint(4, 0.98), DiagramPoint(4, 0)],
        ballId: 'r1',
        pocket: DiagramPocket.tm,
      ),
      DiagramArrow(
        id: 'a2',
        kind: DiagramArrowKind.cue,
        path: [DiagramPoint(2.43, 3.64), DiagramPoint(4, 1.25)],
        ballId: 'w',
      ),
      DiagramArrow(
        id: 'a3',
        kind: DiagramArrowKind.cue,
        path: [DiagramPoint(5.57, 3.64), DiagramPoint(4, 1.25)],
        ballId: 'w',
      ),
    ],
  ),
);

/// Les six repères avec le médaillon de la quantité de bille (`inset` de la
/// transcription : demi-bille, point d'impact au centre).
final sixPositionsInset = DiagramExample(
  name: 'Six repères avec médaillon (demi-bille)',
  source: 'entrainement/p05.yaml#entrainement-p05-e1',
  description: sixPositions.description,
  spec: sixPositions.spec.copyWith(
    inset: const DiagramInset(contact: ContactFraction.half),
  ),
);

/// Blanche à 0,4 case de la bande de droite, jouée vers la gauche : le talon
/// de la queue serait coupé par le rail, il est raccourci pour y rester.
const againstTheRail = DiagramExample(
  name: 'Queue contre la bande',
  source: 'illustratif (hors transcription)',
  description: 'Blanche contre la bande : la queue reste dans la table.',
  spec: TableDiagramSpec(
    id: 'against-the-rail',
    balls: [
      DiagramBall(
        id: 'w',
        color: BallKind.white,
        at: DiagramPoint(7.6, 2),
        role: DiagramBallRole.cue,
      ),
      DiagramBall(id: 'y1', color: BallKind.yellow, at: DiagramPoint(4, 2)),
    ],
    steps: [DiagramStep(cueId: 'w', hitId: 'y1', pocket: DiagramPocket.tl)],
  ),
);

/// Tous les exemples, pour les knobs.
const List<DiagramExample> diagramExamples = [
  fullBall,
  halfBall,
  sixPositions,
  againstTheRail,
  powerGame,
  twoCushions,
];
