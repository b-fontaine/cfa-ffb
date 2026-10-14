import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/ui/table_diagram/diagram_timeline.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';
import 'package:billard_cfa/shared/ui/table_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les positions attendues sont calculées à la main (triangles 3-4-5,
/// segments axiaux) et ne dépendent pas de l'implémentation.

Matcher _at(double x, double y, [double epsilon = 1e-9]) =>
    predicate<DiagramPoint>(
      (p) => (p.x - x).abs() < epsilon && (p.y - y).abs() < epsilon,
      'is at ($x, $y)',
    );

/// Distance blanche - bille de but au contact : s = (24,0 + 25,4) / 231,25
/// = 0,213622 case (et non plus 2 x 0,1).
const _s = 0.213622;

const _cue = DiagramBall(
  id: 'w',
  color: BallKind.white,
  at: DiagramPoint(4, 3.2),
  role: DiagramBallRole.cue,
);
const _target = DiagramBall(
  id: 'y1',
  color: BallKind.yellow,
  at: DiagramPoint(4, 2),
);

void main() {
  group('DiagramPolyline', () {
    const line = DiagramPolyline([
      DiagramPoint(0, 0),
      DiagramPoint(3, 0),
      DiagramPoint(3, 4),
    ]);

    test('measures the broken line', () {
      expect(line.length, 7);
    });

    test('moves at constant speed along the broken line', () {
      expect(line.pointAt(0), _at(0, 0));
      expect(line.pointAt(2), _at(2, 0));
      expect(line.pointAt(3), _at(3, 0));
      expect(line.pointAt(5), _at(3, 2));
      expect(line.pointAt(7), _at(3, 4));
    });

    test('clamps the distance to the line', () {
      expect(line.pointAt(-1), _at(0, 0));
      expect(line.pointAt(99), _at(3, 4));
    });

    test('a single point has no length and no direction', () {
      const dot = DiagramPolyline([DiagramPoint(1, 1)]);
      expect(dot.length, 0);
      expect(dot.pointAt(5), _at(1, 1));
      expect(dot.startAngle, isNull);
    });

    test('gives the direction of the first segment (clockwise, 0 = right)', () {
      expect(line.startAngle, 0);
      const down = DiagramPolyline([DiagramPoint(1, 1), DiagramPoint(1, 3)]);
      expect(down.startAngle, closeTo(1.5707963267948966, 1e-12));
    });

    test('skips zero-length segments when reading the direction', () {
      const line = DiagramPolyline([
        DiagramPoint(1, 1),
        DiagramPoint(1, 1),
        DiagramPoint(0, 1),
      ]);
      expect(line.startAngle, closeTo(3.141592653589793, 1e-12));
    });
  });

  group('DiagramTimeline without arrows', () {
    // Cible en (4, 2), poche tm en (4, 0) : la blanche vise (4, 2,213622) (à
    // s = r_c + r_o derrière la cible) depuis (4, 3.2), soit 0,986378 ; la
    // cible parcourt 2.
    const spec = TableDiagramSpec(
      id: 's',
      balls: [_cue, _target],
      steps: [
        DiagramStep(
          cueId: 'w',
          hitId: 'y1',
          contact: ContactFraction.full,
          pocket: DiagramPocket.tm,
        ),
      ],
    );
    final timeline = DiagramTimeline.from(spec);

    test('stops the cue ball at r_c + r_o from the target, not 2 r_o', () {
      final end = timeline.steps.single.cuePath.points.last;

      expect(end, _at(4, 2 + _s, 1e-6));
      expect(end.y - 2, isNot(closeTo(0.2, 1e-3)));
      expect(
        end.y - 2,
        closeTo(BallKind.white.radius + BallKind.yellow.radius, 1e-12),
      );
    });

    test('totals the cue path and the object path', () {
      expect(timeline.totalLength, closeTo(3.2 - 2 - _s + 2, 1e-6));
      expect(timeline.steps, hasLength(1));
      expect(timeline.steps.single.cuePath.length, closeTo(1.2 - _s, 1e-6));
      expect(timeline.steps.single.objectPath.length, closeTo(2, 1e-9));
      expect(timeline.steps.single.pocketed, isTrue);
    });

    test('starts with every ball in place and the cue aimed at the target', () {
      final frame = timeline.frameAt(0);
      expect(frame.balls['w']!.position, _at(4, 3.2));
      expect(frame.balls['y1']!.position, _at(4, 2));
      expect(frame.balls['y1']!.pocketed, isFalse);
      expect(frame.cueAngle, closeTo(-1.5707963267948966, 1e-12));
      expect(frame.stepIndex, 0);
    });

    test('moves the cue ball first, the target only after the contact', () {
      final frame = timeline.frameAt(0.5 / (3.2 - _s));
      expect(frame.balls['w']!.position, _at(4, 2.7, 1e-6));
      expect(frame.balls['y1']!.position, _at(4, 2));
      expect(frame.cueAngle, isNull);
    });

    test('sends the target on after the contact', () {
      // Longueur totale 2,986378 : à la moitié, 1,493189 ; la blanche a fini
      // ses 0,986378, la cible a parcouru 0,506811.
      final frame = timeline.frameAt(0.5);
      expect(frame.balls['w']!.position, _at(4, 2 + _s, 1e-6));
      expect(frame.balls['y1']!.position, _at(4, 1.493189, 1e-6));
      expect(frame.balls['y1']!.pocketed, isFalse);
    });

    test('pockets the target at the end and keeps it at the pocket', () {
      final frame = timeline.frameAt(1);
      expect(frame.balls['y1']!.position, _at(4, 0));
      expect(frame.balls['y1']!.pocketed, isTrue);
      expect(frame.balls['w']!.position, _at(4, 2 + _s, 1e-6));
    });

    test('clamps the time to [0, 1]', () {
      expect(timeline.frameAt(-3).balls['y1']!.position, _at(4, 2));
      expect(timeline.frameAt(4).balls['y1']!.pocketed, isTrue);
    });

    test('converts a duration into a time at constant speed', () {
      final slow = DiagramTimeline.from(spec, casesPerSecond: 2);
      // 2,986378 cases à 2 cases par seconde : 1,493189 s.
      expect(slow.duration, const Duration(milliseconds: 1493));
      final frame = slow.frameAtTime(const Duration(milliseconds: 750));
      // 0,75 s = 1,5 case : 0,986378 pour la blanche, 0,513622 pour la cible.
      expect(frame.balls['y1']!.position, _at(4, 1.486378, 1e-3));
      expect(
        slow.frameAtTime(const Duration(seconds: 60)).balls['y1']!.pocketed,
        isTrue,
      );
    });

    test('exposes the initial and the final frames', () {
      expect(timeline.initialFrame.balls['y1']!.pocketed, isFalse);
      expect(timeline.finalFrame.balls['y1']!.pocketed, isTrue);
    });
  });

  group('DiagramTimeline with a cue ball that bounces', () {
    // Blanche (1,3) -> bande haute (2.5,1) -> (4,3) : 2 x 2,5 = 5 ; la cible
    // en (4, 3.2) part ensuite vers la poche bm (4, 4) : 0,8.
    const spec = TableDiagramSpec(
      id: 'bank',
      balls: [
        DiagramBall(id: 'w', color: BallKind.white, at: DiagramPoint(1, 3)),
        DiagramBall(id: 'y1', color: BallKind.yellow, at: DiagramPoint(4, 3.2)),
      ],
      arrows: [
        DiagramArrow(
          id: 'a1',
          kind: DiagramArrowKind.cue,
          ballId: 'w',
          path: [DiagramPoint(1, 3), DiagramPoint(2.5, 1), DiagramPoint(4, 3)],
          bounces: [DiagramBand.top],
        ),
        DiagramArrow(
          id: 'a2',
          kind: DiagramArrowKind.object,
          ballId: 'y1',
          path: [DiagramPoint(4, 3.2), DiagramPoint(4, 4)],
          pocket: DiagramPocket.bm,
        ),
      ],
      steps: [DiagramStep(cueId: 'w', hitId: 'y1')],
    );
    final timeline = DiagramTimeline.from(spec);

    test('follows the drawn path, rebound included', () {
      expect(timeline.totalLength, closeTo(5.8, 1e-9));
      expect(timeline.frameAt(2.5 / 5.8).balls['w']!.position, _at(2.5, 1));
      expect(timeline.frameAt(3.75 / 5.8).balls['w']!.position, _at(3.25, 2));
    });

    test('lets the target leave once the cue ball has arrived', () {
      final atContact = timeline.frameAt(5 / 5.8);
      expect(atContact.balls['w']!.position, _at(4, 3));
      expect(atContact.balls['y1']!.position, _at(4, 3.2));
      final after = timeline.frameAt(5.4 / 5.8);
      expect(after.balls['y1']!.position, _at(4, 3.6));
    });

    test('takes the pocket from the arrow when the step has none', () {
      expect(timeline.steps.single.pocketed, isTrue);
      expect(timeline.finalFrame.balls['y1']!.pocketed, isTrue);
      expect(timeline.finalFrame.balls['y1']!.position, _at(4, 4));
    });
  });

  group('DiagramTimeline with numbered cue positions', () {
    // La blanche part de g1 (4, 3.4) puis de g2 (3.1, 3.4) ; la flèche issue de
    // g2 mesure 1,5 (0,9 ; 1,2) ; celle issue de g1 est absente : la blanche
    // vise le contact en (4, 2,213622), soit 3,4 - 2,213622 = 1,186378.
    const spec = TableDiagramSpec(
      id: 'quantities',
      balls: [
        DiagramBall(id: 'w', color: BallKind.white, at: DiagramPoint(4, 3.4)),
        DiagramBall(id: 'y1', color: BallKind.yellow, at: DiagramPoint(4, 2)),
      ],
      ghosts: [
        DiagramGhost(
          id: 'g1',
          at: DiagramPoint(4, 3.4),
          role: DiagramGhostRole.cueStart,
          label: '1',
        ),
        DiagramGhost(
          id: 'g2',
          at: DiagramPoint(3.1, 3.4),
          role: DiagramGhostRole.cueStart,
          label: '2',
        ),
      ],
      arrows: [
        DiagramArrow(
          id: 'a1',
          kind: DiagramArrowKind.object,
          ballId: 'y1',
          path: [DiagramPoint(4, 2), DiagramPoint(4, 0)],
          pocket: DiagramPocket.tm,
        ),
        DiagramArrow(
          id: 'a2',
          kind: DiagramArrowKind.cue,
          ballId: 'w',
          path: [DiagramPoint(3.1, 3.4), DiagramPoint(4, 2.2)],
        ),
      ],
      steps: [
        DiagramStep(
          cueId: 'w',
          hitId: 'y1',
          pocket: DiagramPocket.tm,
          fromGhostId: 'g1',
        ),
        DiagramStep(
          cueId: 'w',
          hitId: 'y1',
          pocket: DiagramPocket.tm,
          fromGhostId: 'g2',
        ),
      ],
    );
    final timeline = DiagramTimeline.from(spec);

    test('chooses the arrow that leaves the numbered position', () {
      expect(timeline.steps[0].cuePath.length, closeTo(1.4 - _s, 1e-6));
      expect(timeline.steps[1].cuePath.length, closeTo(1.5, 1e-9));
      expect(timeline.totalLength, closeTo(1.4 - _s + 2 + 1.5 + 2, 1e-6));
    });

    test('starts the second shot from the second position', () {
      final frame = timeline.frameAt(
        timeline.steps[1].startLength / timeline.totalLength,
      );
      expect(frame.stepIndex, 1);
      expect(frame.balls['w']!.position, _at(3.1, 3.4));
      expect(frame.cueAngle, isNotNull);
    });

    test('puts the target back for the second shot', () {
      // Longueur totale 6,686378 ; le premier tir finit à 3,186378. À 0,1 case
      // avant, la cible est à 0,1 de la poche.
      const total = 1.4 - _s + 5.5;
      final earlier = timeline.frameAt((1.4 - _s + 2 - 0.1) / total);
      expect(earlier.balls['y1']!.pocketed, isFalse);
      expect(earlier.balls['y1']!.position, _at(4, 0.1, 1e-6));

      final frame = timeline.frameAt((1.4 - _s + 2 + 0.75) / total);
      expect(frame.balls['w']!.position, _at(3.55, 2.8, 1e-6));
      expect(frame.balls['y1']!.position, _at(4, 2));
      expect(frame.balls['y1']!.pocketed, isFalse);
    });

    test('ends with the target pocketed', () {
      expect(timeline.finalFrame.balls['y1']!.pocketed, isTrue);
      expect(timeline.finalFrame.stepIndex, 1);
    });
  });

  group('DiagramTimeline edge cases', () {
    test('without a step, nothing moves and the duration is zero', () {
      const spec = TableDiagramSpec(id: 'static', balls: [_cue, _target]);
      final timeline = DiagramTimeline.from(spec);
      expect(timeline.isEmpty, isTrue);
      expect(timeline.duration, Duration.zero);
      final frame = timeline.frameAt(0.7);
      expect(frame.balls['w']!.position, _at(4, 3.2));
      expect(frame.stepIndex, -1);
      expect(frame.cueAngle, isNull);
    });

    test('a ball that is hit without a pocket stays where it is', () {
      const spec = TableDiagramSpec(
        id: 'touch',
        balls: [_cue, _target],
        steps: [DiagramStep(cueId: 'w', hitId: 'y1')],
      );
      final timeline = DiagramTimeline.from(spec);
      expect(timeline.steps.single.pocketed, isFalse);
      expect(timeline.steps.single.objectPath.length, 0);
      // Visée droite : la blanche s'arrête à r_c + r_o avant la cible.
      expect(timeline.finalFrame.balls['w']!.position, _at(4, 2 + _s, 1e-6));
      expect(timeline.finalFrame.balls['y1']!.position, _at(4, 2));
    });

    test('a played object ball stops at 2 r_o from the ball it touches', () {
      // Jeu de placement : une bille jaune touche une bille rouge. Les deux
      // rayons sont ceux d'une bille de but : 2 x 0,109838 = 0,219676.
      const spec = TableDiagramSpec(
        id: 'object-on-object',
        balls: [
          DiagramBall(id: 'y1', color: BallKind.yellow, at: DiagramPoint(4, 3)),
          DiagramBall(id: 'r1', color: BallKind.red, at: DiagramPoint(4, 2)),
        ],
        steps: [DiagramStep(cueId: 'y1', hitId: 'r1')],
      );

      final end = DiagramTimeline.from(spec).finalFrame.balls['y1']!.position;

      expect(end, _at(4, 2.219676, 1e-6));
    });

    test('a cue arrow far from the target is replaced by a straight aim', () {
      const spec = TableDiagramSpec(
        id: 'far',
        balls: [_cue, _target],
        arrows: [
          DiagramArrow(
            id: 'a1',
            kind: DiagramArrowKind.cue,
            ballId: 'w',
            path: [DiagramPoint(4, 3.2), DiagramPoint(7, 3.2)],
          ),
        ],
        steps: [DiagramStep(cueId: 'w', hitId: 'y1', pocket: DiagramPocket.tm)],
      );
      expect(
        DiagramTimeline.from(spec).steps.single.cuePath.length,
        closeTo(1.2 - _s, 1e-6),
      );
    });

    test('a cue ball already on the target does not move', () {
      const spec = TableDiagramSpec(
        id: 'same',
        balls: [
          DiagramBall(id: 'w', color: BallKind.white, at: DiagramPoint(2, 2)),
          DiagramBall(id: 'y1', color: BallKind.yellow, at: DiagramPoint(2, 2)),
        ],
        steps: [DiagramStep(cueId: 'w', hitId: 'y1')],
      );
      final timeline = DiagramTimeline.from(spec);
      expect(timeline.totalLength, 0);
      expect(timeline.finalFrame.balls['w']!.position, _at(2, 2));
    });

    test('an object arrow that stops short of the pocket is extended', () {
      const spec = TableDiagramSpec(
        id: 'short',
        balls: [_cue, _target],
        arrows: [
          DiagramArrow(
            id: 'a1',
            kind: DiagramArrowKind.object,
            ballId: 'y1',
            path: [DiagramPoint(4, 2), DiagramPoint(4, 0.3)],
          ),
        ],
        steps: [DiagramStep(cueId: 'w', hitId: 'y1', pocket: DiagramPocket.tm)],
      );
      final timeline = DiagramTimeline.from(spec);
      expect(timeline.steps.single.objectPath.length, closeTo(2, 1e-9));
      expect(timeline.finalFrame.balls['y1']!.position, _at(4, 0));
    });

    test('an object arrow far from the pocket gets the pocket appended', () {
      const spec = TableDiagramSpec(
        id: 'append',
        balls: [_cue, _target],
        arrows: [
          DiagramArrow(
            id: 'a1',
            kind: DiagramArrowKind.object,
            ballId: 'y1',
            path: [DiagramPoint(4, 2), DiagramPoint(2, 2)],
          ),
        ],
        steps: [DiagramStep(cueId: 'w', hitId: 'y1', pocket: DiagramPocket.tm)],
      );
      final timeline = DiagramTimeline.from(spec);
      expect(
        timeline.steps.single.objectPath.length,
        closeTo(2 + 2.8284271247, 1e-6),
      );
      expect(timeline.finalFrame.balls['y1']!.position, _at(4, 0));
    });

    test('rejects a step that names an unknown ball', () {
      const spec = TableDiagramSpec(
        id: 'bad',
        balls: [_cue],
        steps: [DiagramStep(cueId: 'w', hitId: 'nope')],
      );
      expect(
        () => DiagramTimeline.from(spec),
        throwsA(isA<InvalidDiagramException>()),
      );
      const bad2 = TableDiagramSpec(
        id: 'bad2',
        balls: [_target],
        steps: [DiagramStep(cueId: 'nope', hitId: 'y1')],
      );
      expect(
        () => DiagramTimeline.from(bad2),
        throwsA(isA<InvalidDiagramException>()),
      );
    });

    test('rejects a step that names an unknown cue position', () {
      const spec = TableDiagramSpec(
        id: 'bad',
        balls: [_cue, _target],
        steps: [DiagramStep(cueId: 'w', hitId: 'y1', fromGhostId: 'g9')],
      );
      expect(
        () => DiagramTimeline.from(spec),
        throwsA(isA<InvalidDiagramException>()),
      );
    });
  });

  group('DiagramTimeline repeat', () {
    // « x 4 » est une consigne d'exercice : le tir n'est joué qu'une fois.
    TableDiagramSpec spec(int repeat) => TableDiagramSpec(
      id: 'repeat',
      balls: const [_cue, _target],
      steps: [
        DiagramStep(
          cueId: 'w',
          hitId: 'y1',
          pocket: DiagramPocket.tm,
          repeat: repeat,
        ),
      ],
    );

    test('plays the shot once whatever the number of repetitions', () {
      final once = DiagramTimeline.from(spec(1));
      final four = DiagramTimeline.from(spec(4));
      expect(four.steps, hasLength(1));
      expect(four.totalLength, closeTo(3.2 - _s, 1e-6));
      expect(four.totalLength, once.totalLength);
      expect(four.duration, once.duration);
      expect(four.finalFrame.balls['y1']!.pocketed, isTrue);
      expect(four.finalFrame.stepIndex, 0);
    });
  });

  group('DiagramTimeline tolerances', () {
    // Blanche (4 ; 3), cible (4 ; 0) : sans flèche retenue, la blanche vise la
    // cible et s'arrête à r_c + r_o avant elle, soit 3 - 0,213622 = 2,786378.
    const cue = DiagramBall(
      id: 'w',
      color: BallKind.white,
      at: DiagramPoint(4, 3),
    );
    const target = DiagramBall(
      id: 'y1',
      color: BallKind.yellow,
      at: DiagramPoint(4, 0),
    );

    double cueLength(double endY) {
      final spec = TableDiagramSpec(
        id: 'arrow-$endY',
        balls: const [cue, target],
        arrows: [
          DiagramArrow(
            id: 'a1',
            kind: DiagramArrowKind.cue,
            ballId: 'w',
            path: [const DiagramPoint(4, 3), DiagramPoint(4, endY)],
          ),
        ],
        steps: const [DiagramStep(cueId: 'w', hitId: 'y1')],
      );
      return DiagramTimeline.from(spec).steps.single.cuePath.length;
    }

    test('keeps a cue arrow that ends just inside 0,6 of the target', () {
      expect(cueLength(0.59), closeTo(3 - 0.59, 1e-9));
    });

    test('keeps a cue arrow that ends exactly 0,6 from the target', () {
      expect(cueLength(0.6), closeTo(2.4, 1e-9));
    });

    test('replaces a cue arrow that ends beyond 0,6 by a straight aim', () {
      expect(cueLength(0.61), closeTo(3 - _s, 1e-6));
    });

    // Cercle `cue_start` en (0 ; 3) ; la flèche de la blanche part de
    // (d ; 3) vers (4 ; 3) (longueur 4 - d + d = 4 depuis le cercle). Sans
    // flèche retenue, la blanche vise la cible (4 ; 0) depuis le cercle :
    // 5 - 0,213622 = 4,786378.
    double ghostCueLength(double startX) {
      final spec = TableDiagramSpec(
        id: 'ghost-$startX',
        balls: const [cue, target],
        ghosts: const [
          DiagramGhost(
            id: 'g1',
            at: DiagramPoint(0, 3),
            role: DiagramGhostRole.cueStart,
          ),
        ],
        arrows: [
          DiagramArrow(
            id: 'a1',
            kind: DiagramArrowKind.cue,
            ballId: 'w',
            path: [DiagramPoint(startX, 3), const DiagramPoint(4, 3)],
          ),
        ],
        steps: const [DiagramStep(cueId: 'w', hitId: 'y1', fromGhostId: 'g1')],
      );
      return DiagramTimeline.from(spec).steps.single.cuePath.length;
    }

    test('keeps an arrow that leaves 0,19 from its cue position', () {
      expect(ghostCueLength(0.19), closeTo(4, 1e-9));
    });

    test('keeps an arrow that leaves exactly 0,2 from its cue position', () {
      expect(ghostCueLength(0.2), closeTo(4, 1e-9));
    });

    test('ignores an arrow that leaves 0,21 from its cue position', () {
      expect(ghostCueLength(0.21), closeTo(5 - _s, 1e-6));
    });
  });

  group('DiagramTimeline outside the table', () {
    // La table couvre [0 ; 8] x [0 ; 4], bords compris (poches aux coins) :
    // un schéma qui en sort est une erreur de transcription, refusée.
    TableDiagramSpec ballAt(double x, double y) => TableDiagramSpec(
      id: 'ball',
      balls: [
        DiagramBall(id: 'w', color: BallKind.white, at: DiagramPoint(x, y)),
      ],
    );

    test('accepts the four corners of the table', () {
      for (final p in const [(0.0, 0.0), (8.0, 0.0), (0.0, 4.0), (8.0, 4.0)]) {
        final frame = DiagramTimeline.from(ballAt(p.$1, p.$2)).initialFrame;
        expect(frame.balls['w']!.position, _at(p.$1, p.$2));
      }
    });

    test('rejects a ball beyond each side of the table', () {
      for (final p in const [
        (-0.01, 2.0),
        (8.01, 2.0),
        (4.0, -0.01),
        (4.0, 4.01),
      ]) {
        expect(
          () => DiagramTimeline.from(ballAt(p.$1, p.$2)),
          throwsA(isA<InvalidDiagramException>()),
          reason: '$p',
        );
      }
    });

    test('rejects a cue position outside the table', () {
      const spec = TableDiagramSpec(
        id: 'ghost',
        balls: [_cue],
        ghosts: [
          DiagramGhost(
            id: 'g1',
            at: DiagramPoint(9, 1),
            role: DiagramGhostRole.cueStart,
          ),
        ],
      );
      expect(
        () => DiagramTimeline.from(spec),
        throwsA(isA<InvalidDiagramException>()),
      );
    });

    test('rejects a cue or object arrow point outside the table', () {
      for (final kind in const [
        DiagramArrowKind.cue,
        DiagramArrowKind.object,
      ]) {
        final spec = TableDiagramSpec(
          id: 'arrow',
          balls: const [_cue],
          arrows: [
            DiagramArrow(
              id: 'a1',
              kind: kind,
              path: const [DiagramPoint(4, 3), DiagramPoint(4, 4.5)],
            ),
          ],
        );
        expect(
          () => DiagramTimeline.from(spec),
          throwsA(isA<InvalidDiagramException>()),
          reason: '$kind',
        );
      }
    });

    test('rejects an arrow point just beyond each side, accepts the edge', () {
      TableDiagramSpec withArrowEnd(
        DiagramArrowKind kind,
        double x,
        double y,
      ) => TableDiagramSpec(
        id: 'edge',
        balls: const [_cue],
        arrows: [
          DiagramArrow(
            id: 'a1',
            kind: kind,
            path: [const DiagramPoint(4, 2), DiagramPoint(x, y)],
          ),
        ],
      );
      for (final kind in const [
        DiagramArrowKind.cue,
        DiagramArrowKind.object,
      ]) {
        for (final p in const [
          (-0.01, 2.0),
          (8.01, 2.0),
          (4.0, -0.01),
          (4.0, 4.01),
        ]) {
          expect(
            () => DiagramTimeline.from(withArrowEnd(kind, p.$1, p.$2)),
            throwsA(isA<InvalidDiagramException>()),
            reason: '$kind $p',
          );
        }
        for (final p in const [
          (0.0, 2.0),
          (8.0, 2.0),
          (4.0, 0.0),
          (4.0, 4.0),
        ]) {
          expect(
            DiagramTimeline.from(withArrowEnd(kind, p.$1, p.$2)),
            isA<DiagramTimeline>(),
            reason: '$kind $p',
          );
        }
      }
    });

    test('accepts a cue_start circle on the corner, rejects it past it', () {
      TableDiagramSpec withGhost(double x, double y) => TableDiagramSpec(
        id: 'ghost-edge',
        balls: const [_cue],
        ghosts: [
          DiagramGhost(
            id: 'g1',
            at: DiagramPoint(x, y),
            role: DiagramGhostRole.cueStart,
          ),
        ],
      );
      expect(DiagramTimeline.from(withGhost(8, 4)), isA<DiagramTimeline>());
      expect(
        () => DiagramTimeline.from(withGhost(8.01, 4)),
        throwsA(isA<InvalidDiagramException>()),
      );
      expect(
        () => DiagramTimeline.from(withGhost(8, 4.01)),
        throwsA(isA<InvalidDiagramException>()),
      );
    });

    test('accepts an indication line extending past the cushion', () {
      // Une ligne de visée se prolonge au-delà de la bande sur les schémas.
      const spec = TableDiagramSpec(
        id: 'aim',
        balls: [_cue],
        arrows: [
          DiagramArrow(
            id: 'a1',
            kind: DiagramArrowKind.indication,
            path: [DiagramPoint(4, 3), DiagramPoint(4, 4.5)],
          ),
        ],
      );
      expect(DiagramTimeline.from(spec).initialFrame.balls, contains('w'));
    });
  });

  group('DiagramTimeline with several rebounds', () {
    // Blanche (0 ; 4) -> bande haute (3 ; 0) -> bande basse (6 ; 4) -> cible
    // (6 ; 1) : 5 + 5 + 3 = 13 (triangles 3-4-5).
    const spec = TableDiagramSpec(
      id: 'double-bank',
      balls: [
        DiagramBall(id: 'w', color: BallKind.white, at: DiagramPoint(0, 4)),
        DiagramBall(id: 'y1', color: BallKind.yellow, at: DiagramPoint(6, 1)),
      ],
      arrows: [
        DiagramArrow(
          id: 'a1',
          kind: DiagramArrowKind.cue,
          ballId: 'w',
          path: [
            DiagramPoint(0, 4),
            DiagramPoint(3, 0),
            DiagramPoint(6, 4),
            DiagramPoint(6, 1),
          ],
          bounces: [DiagramBand.top, DiagramBand.bottom],
        ),
      ],
      steps: [DiagramStep(cueId: 'w', hitId: 'y1')],
    );
    final timeline = DiagramTimeline.from(spec);

    test('adds up the length of every segment', () {
      expect(timeline.totalLength, closeTo(13, 1e-9));
      expect(timeline.steps.single.cuePath.length, closeTo(13, 1e-9));
    });

    test('goes through both rebound points', () {
      expect(timeline.frameAt(5 / 13).balls['w']!.position, _at(3, 0));
      expect(timeline.frameAt(10 / 13).balls['w']!.position, _at(6, 4));
      expect(timeline.frameAt(11.5 / 13).balls['w']!.position, _at(6, 2.5));
      expect(timeline.finalFrame.balls['w']!.position, _at(6, 1));
    });
  });

  group('model', () {
    test('points compare by value and interpolate', () {
      expect(const DiagramPoint(1, 2), const DiagramPoint(1, 2));
      expect(
        const DiagramPoint(1, 2).hashCode,
        const DiagramPoint(1, 2).hashCode,
      );
      expect(
        const DiagramPoint(0, 0).lerp(const DiagramPoint(4, 2), 0.5),
        _at(2, 1),
      );
      expect(const DiagramPoint(0, 0).distanceTo(const DiagramPoint(3, 4)), 5);
      expect(const DiagramPoint(1, 2).toString(), 'Point(1.0, 2.0)');
    });

    test('pockets sit at the centres given by the FORMAT', () {
      expect(DiagramPocket.tl.point, _at(0, 0));
      expect(DiagramPocket.tm.point, _at(4, 0));
      expect(DiagramPocket.tr.point, _at(8, 0));
      expect(DiagramPocket.bl.point, _at(0, 4));
      expect(DiagramPocket.bm.point, _at(4, 4));
      expect(DiagramPocket.br.point, _at(8, 4));
    });

    test('pockets agree with the table geometry', () {
      for (final pocket in TablePocket.values) {
        final model = DiagramPocket.values.byName(pocket.name).point;
        expect(model.x, pocket.position.dx);
        expect(model.y, pocket.position.dy);
      }
    });

    test('bounce points are the inner points when they match the bands', () {
      const arrow = DiagramArrow(
        id: 'a',
        kind: DiagramArrowKind.cue,
        path: [DiagramPoint(0, 3), DiagramPoint(1, 0), DiagramPoint(2, 3)],
        bounces: [DiagramBand.top],
      );
      expect(arrow.bouncePoints, [const DiagramPoint(1, 0)]);
      const noBounce = DiagramArrow(
        id: 'b',
        kind: DiagramArrowKind.cue,
        path: [DiagramPoint(0, 3), DiagramPoint(1, 0), DiagramPoint(2, 3)],
      );
      expect(noBounce.bouncePoints, isEmpty);
    });

    test('a bounce on each band gives the inner point', () {
      for (final band in DiagramBand.values) {
        final arrow = DiagramArrow(
          id: band.name,
          kind: DiagramArrowKind.cue,
          path: const [
            DiagramPoint(1, 1),
            DiagramPoint(2, 0),
            DiagramPoint(3, 1),
          ],
          bounces: [band],
        );
        expect(arrow.bouncePoints, [const DiagramPoint(2, 0)], reason: '$band');
      }
    });

    test('two bounces give the two inner points of a four-point path', () {
      const arrow = DiagramArrow(
        id: 'a',
        kind: DiagramArrowKind.cue,
        path: [
          DiagramPoint(0, 4),
          DiagramPoint(3, 0),
          DiagramPoint(6, 4),
          DiagramPoint(6, 1),
        ],
        bounces: [DiagramBand.top, DiagramBand.bottom],
      );
      expect(arrow.bouncePoints, [
        const DiagramPoint(3, 0),
        const DiagramPoint(6, 4),
      ]);
    });

    test('a count of bounces that does not fit the path gives no point', () {
      const arrow = DiagramArrow(
        id: 'a',
        kind: DiagramArrowKind.cue,
        path: [
          DiagramPoint(0, 4),
          DiagramPoint(3, 0),
          DiagramPoint(6, 4),
          DiagramPoint(6, 1),
        ],
        bounces: [DiagramBand.top],
      );
      expect(arrow.bouncePoints, isEmpty);
      const tooMany = DiagramArrow(
        id: 'b',
        kind: DiagramArrowKind.cue,
        path: [DiagramPoint(0, 4), DiagramPoint(3, 0), DiagramPoint(6, 4)],
        bounces: [DiagramBand.top, DiagramBand.bottom],
      );
      expect(tooMany.bouncePoints, isEmpty);
    });
  });

  group('DiagramTimeline with a step that touches no ball', () {
    // La bille noire est jouée seule (jeu « placer la noire ») : elle suit sa
    // flèche de (1, 2) à (6, 2), sans toucher personne.
    const black = DiagramBall(
      id: 'k',
      color: BallKind.black,
      at: DiagramPoint(1, 2),
      role: DiagramBallRole.object,
    );
    const spec = TableDiagramSpec(
      id: 'solo',
      balls: [black, _target],
      arrows: [
        DiagramArrow(
          id: 'a1',
          kind: DiagramArrowKind.object,
          ballId: 'k',
          path: [DiagramPoint(1, 2), DiagramPoint(6, 2)],
        ),
      ],
      steps: [DiagramStep(cueId: 'k', repeat: 5)],
    );
    final timeline = DiagramTimeline.from(spec);

    test('has no ball hit and nothing pocketed', () {
      expect(timeline.steps.single.hitId, isNull);
      expect(timeline.steps.single.pocketed, isFalse);
      expect(timeline.finalFrame.balls.values.any((b) => b.pocketed), isFalse);
    });

    test('moves the played ball along its own arrow', () {
      expect(timeline.totalLength, closeTo(5, 1e-9));
      expect(timeline.frameAt(0.5).balls['k']!.position, _at(3.5, 2));
      expect(timeline.finalFrame.balls['k']!.position, _at(6, 2));
    });

    test('leaves the other balls where they are', () {
      expect(timeline.finalFrame.balls['y1']!.position, _at(4, 2));
    });

    test('keeps the played ball still when it has no arrow', () {
      final still = DiagramTimeline.from(
        const TableDiagramSpec(
          id: 'still',
          balls: [black],
          steps: [DiagramStep(cueId: 'k')],
        ),
      );
      expect(still.totalLength, 0);
      expect(still.finalFrame.balls['k']!.position, _at(1, 2));
    });
  });

  group('Reading hints kept by the model', () {
    test('have neutral defaults', () {
      const step = DiagramStep(cueId: 'w');
      expect(step.hitId, isNull);
      expect(step.extras, isEmpty);
      const ball = DiagramBall(
        id: 'y1',
        color: BallKind.yellow,
        at: DiagramPoint(1, 1),
      );
      expect(ball.order, isNull);
      const arrow = DiagramArrow(
        id: 'a',
        kind: DiagramArrowKind.cue,
        path: [DiagramPoint(0, 0), DiagramPoint(1, 1)],
      );
      expect(arrow.label, isNull);
      expect(arrow.note, isNull);
      const zone = DiagramZone(
        id: 'z',
        from: DiagramPoint(0, 0),
        to: DiagramPoint(1, 1),
      );
      expect(zone.label, isNull);
    });
  });

  group('single source of truth', () {
    test('the table geometry takes its dimensions from the diagram layout', () {
      expect(TableGeometry.columns, DiagramLayout.columns);
      expect(TableGeometry.rows, DiagramLayout.rows);
      expect(TableGeometry.headStringX, DiagramLayout.headStringX);
      expect(DiagramLayout.headStringX, closeTo(1.6, 1e-12));
      expect(TableGeometry.objectBallRadius, BallKind.red.radius);
      expect(TableGeometry.cueBallRadius, BallKind.white.radius);
    });

    test('every table pocket is a diagram pocket with the same position', () {
      expect(TablePocket.values, hasLength(DiagramPocket.values.length));
      for (final pocket in TablePocket.values) {
        expect(pocket.source.name, pocket.name);
        expect(pocket.position.dx, pocket.source.point.x);
        expect(pocket.position.dy, pocket.source.point.y);
      }
    });
  });

  group('value equality of the spec', () {
    TableDiagramSpec build({String label = 'x4'}) => TableDiagramSpec(
      id: 'eq',
      balls: [
        DiagramBall(
          id: 'y1',
          color: BallKind.yellow,
          at: const DiagramPoint(4, 2),
          label: label,
        ),
      ],
      arrows: const [
        DiagramArrow(
          id: 'a1',
          kind: DiagramArrowKind.cue,
          path: [DiagramPoint(4, 3), DiagramPoint(4, 2)],
        ),
      ],
      steps: const [
        DiagramStep(cueId: 'y1', extras: {'effect': 'none'}),
      ],
    );

    test('two specs with the same content are equal', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('a different nested field makes the specs different', () {
      expect(build(label: 'x5'), isNot(build()));
    });

    test('the timeline of one spec instance is computed once', () {
      final spec = build();
      expect(
        identical(DiagramTimeline.of(spec), DiagramTimeline.of(spec)),
        isTrue,
      );
    });

    test('the cached timeline reports the same errors as from', () {
      const bad = TableDiagramSpec(
        id: 'bad',
        balls: [
          DiagramBall(id: 'w', color: BallKind.white, at: DiagramPoint(9, 9)),
        ],
      );
      expect(
        () => DiagramTimeline.of(bad),
        throwsA(isA<InvalidDiagramException>()),
      );
    });
  });
}
