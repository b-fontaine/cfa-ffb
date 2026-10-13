import 'dart:math' show Point;

import 'package:billard_cfa/entities/session_sheet/presentation/illustration_mapper.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';
import 'package:billard_cfa/shared/ui/angle_mark.dart';
import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart';
import 'package:billard_cfa/shared/ui/contact_strip.dart';
import 'package:billard_cfa/shared/ui/cue_side_view.dart';
import 'package:billard_cfa/shared/ui/ghost_aim_diagram.dart';
import 'package:billard_cfa/shared/ui/pdf_page_chip.dart';
import 'package:billard_cfa/shared/ui/power_scale.dart';
import 'package:billard_cfa/shared/ui/stance_diagram.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_player.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart'
    as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../shared/ui/pump_ui.dart';

const _diagrams = {
  'initiation-p07-e1': ui.TableDiagramSpec(
    id: 'initiation-p07-e1',
    balls: [
      ui.DiagramBall(
        id: 'w',
        color: ui.BallKind.white,
        at: ui.DiagramPoint(2, 2),
        role: ui.DiagramBallRole.cue,
      ),
      ui.DiagramBall(
        id: 'r',
        color: ui.BallKind.red,
        at: ui.DiagramPoint(4, 2),
      ),
    ],
    steps: [
      ui.DiagramStep(cueId: 'w', hitId: 'r', pocket: ui.DiagramPocket.tm),
    ],
  ),
};

/// Une illustration de chaque type de la liste fermée du FORMAT (§ 6), et le
/// composant du design system attendu.
final _all = <(Illustration, Type)>[
  (
    const Illustration.diagramRef(
      id: 'ref',
      caption: 'Légende',
      alt: 'Alt ref',
      diagramId: 'initiation-p07-e1',
    ),
    TableDiagramPlayer,
  ),
  (
    const Illustration.table(
      id: 'table',
      caption: 'Légende',
      alt: 'Alt table',
      balls: [
        IllustrationBall(
          id: 'w',
          color: IllustrationBallColor.white,
          at: Point(2, 2),
          role: IllustrationBallRole.cue,
        ),
        IllustrationBall(
          id: 'r',
          color: IllustrationBallColor.red,
          at: Point(4, 2),
          role: IllustrationBallRole.object,
        ),
      ],
      steps: [
        IllustrationStep(
          cueId: 'w',
          hitId: 'r',
          contact: ContactFraction.half,
          pocket: TablePocket.tm,
        ),
      ],
    ),
    TableDiagramPlayer,
  ),
  (
    const Illustration.contact(
      id: 'contact',
      caption: 'Légende',
      alt: 'Alt contact',
      fraction: ContactFraction.half,
      tipPoint: TipPoint.topLeft,
    ),
    BallContactDiagram,
  ),
  (
    const Illustration.contactStrip(
      id: 'strip',
      caption: 'Légende',
      alt: 'Alt strip',
      fractions: [ContactFraction.full, ContactFraction.half],
      highlight: ContactFraction.half,
    ),
    ContactStrip,
  ),
  (
    const Illustration.ghostAim(
      id: 'aim',
      caption: 'Légende',
      alt: 'Alt aim',
      cue: Point(1.84, 2.31),
      object: Point(5, 2),
      pocket: TablePocket.tr,
      fraction: ContactFraction.half,
    ),
    GhostAimDiagram,
  ),
  (
    const Illustration.cueSide(
      id: 'side',
      caption: 'Légende',
      alt: 'Alt side',
      tipPoint: TipPoint.top,
      cueHeight: CueHeight.high,
    ),
    CueSideView,
  ),
  (
    const Illustration.stanceTop(
      id: 'stance',
      caption: 'Légende',
      alt: 'Alt stance',
      annotations: ['Pieds écartés.'],
    ),
    StanceDiagram,
  ),
  (
    const Illustration.powerScale(
      id: 'power',
      caption: 'Légende',
      alt: 'Alt power',
      levels: 5,
      highlight: 3,
      distanceLabel: 'Zone grise',
    ),
    PowerScale,
  ),
  (
    const Illustration.angle(
      id: 'angle',
      caption: 'Légende',
      alt: 'Alt angle',
      kind: AngleKind.rightAngle,
      vertex: Point(4, 2),
      rays: [Point(6, 2), Point(4, 0.5)],
    ),
    AngleMark,
  ),
  (
    const Illustration.pdfRef(
      id: 'pdf',
      caption: 'Légende',
      alt: 'Alt pdf',
      file: 'Fiches techniques CFA BàP.pdf',
      page: 15,
    ),
    PdfPageChip,
  ),
];

void main() {
  group('the ten illustration types', () {
    for (final (illustration, type) in _all) {
      testWidgets('${illustration.id} renders as $type', (tester) async {
        await pumpUi(
          tester,
          SingleChildScrollView(
            child: Builder(
              builder: (context) => IllustrationMapper.build(
                context,
                illustration,
                diagrams: _diagrams,
              ),
            ),
          ),
        );

        expect(find.byType(type), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('${illustration.id} is read by its alternative text', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpUi(
          tester,
          SingleChildScrollView(
            child: Builder(
              builder: (context) => IllustrationMapper.build(
                context,
                illustration,
                diagrams: _diagrams,
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel(illustration.alt), findsOneWidget);
        handle.dispose();
      });
    }
  });

  testWidgets('says so when the referenced diagram is not available', (
    tester,
  ) async {
    await pumpUi(
      tester,
      Builder(
        builder: (context) => IllustrationMapper.build(
          context,
          const Illustration.diagramRef(
            id: 'ref',
            caption: 'Légende',
            alt: 'Alt',
            diagramId: 'inconnu',
          ),
          diagrams: const {},
        ),
      ),
    );

    expect(find.text('This diagram is unavailable.'), findsOneWidget);
  });

  group('table specification', () {
    test('carries balls, ghosts, arrows, zones and steps', () {
      const table = TableIllustration(
        id: 't',
        caption: 'c',
        alt: 'a',
        balls: [
          IllustrationBall(
            id: 'w',
            color: IllustrationBallColor.white,
            at: Point(1, 1),
            role: IllustrationBallRole.cue,
            label: 'x',
            order: 1,
          ),
          IllustrationBall(
            id: 'y',
            color: IllustrationBallColor.yellow,
            at: Point(2, 1),
            role: IllustrationBallRole.object,
          ),
          IllustrationBall(
            id: 'k',
            color: IllustrationBallColor.black,
            at: Point(3, 1),
            role: IllustrationBallRole.obstacle,
          ),
          IllustrationBall(
            id: 'r',
            color: IllustrationBallColor.red,
            at: Point(4, 1),
          ),
        ],
        ghosts: [
          IllustrationGhost(
            id: 'g1',
            at: Point(1, 3),
            role: IllustrationGhostRole.cueStart,
            forBallId: 'w',
            label: '1',
          ),
          IllustrationGhost(
            id: 'g2',
            at: Point(3, 3),
            role: IllustrationGhostRole.impact,
          ),
        ],
        arrows: [
          IllustrationArrow(
            id: 'a1',
            kind: IllustrationArrowKind.object,
            path: [Point(4, 1), Point(4, 0), Point(5, 0.5)],
            ballId: 'r',
            bounces: [IllustrationBand.top],
            pocket: TablePocket.tr,
            label: 'l',
            note: 'n',
          ),
          IllustrationArrow(
            id: 'a2',
            kind: IllustrationArrowKind.cue,
            path: [Point(1, 1), Point(2, 1)],
            bounces: [
              IllustrationBand.bottom,
              IllustrationBand.left,
              IllustrationBand.right,
            ],
          ),
          IllustrationArrow(
            id: 'a3',
            kind: IllustrationArrowKind.indication,
            path: [Point(1, 1), Point(2, 1)],
          ),
        ],
        zones: [
          IllustrationZone(
            id: 'z',
            from: Point(0, 0),
            to: Point(1, 1),
            label: 'zone',
          ),
        ],
        steps: [
          IllustrationStep(
            cueId: 'w',
            hitId: 'r',
            contact: ContactFraction.quarter,
            pocket: TablePocket.bl,
            repeat: 3,
            fromGhostId: 'g1',
            extras: {'effect': 'retro'},
          ),
        ],
      );

      final spec = IllustrationMapper.tableSpecOf(table);

      expect(spec.id, 't');
      expect(spec.balls.map((b) => b.color), [
        ui.BallKind.white,
        ui.BallKind.yellow,
        ui.BallKind.black,
        ui.BallKind.red,
      ]);
      expect(spec.balls.map((b) => b.role), [
        ui.DiagramBallRole.cue,
        ui.DiagramBallRole.object,
        ui.DiagramBallRole.obstacle,
        null,
      ]);
      expect(spec.balls.first.label, 'x');
      expect(spec.balls.first.order, 1);
      expect(spec.ghosts.map((g) => g.role), [
        ui.DiagramGhostRole.cueStart,
        ui.DiagramGhostRole.impact,
      ]);
      expect(spec.ghosts.first.forBallId, 'w');
      expect(spec.arrows.map((a) => a.kind), [
        ui.DiagramArrowKind.object,
        ui.DiagramArrowKind.cue,
        ui.DiagramArrowKind.indication,
      ]);
      expect(spec.arrows.first.pocket, ui.DiagramPocket.tr);
      expect(spec.arrows[1].bounces, [
        ui.DiagramBand.bottom,
        ui.DiagramBand.left,
        ui.DiagramBand.right,
      ]);
      expect(spec.zones.single.label, 'zone');
      final step = spec.steps.single;
      expect(step.contact, ContactFraction.quarter);
      expect(step.pocket, ui.DiagramPocket.bl);
      expect(step.repeat, 3);
      expect(step.fromGhostId, 'g1');
      expect(step.extras, {'effect': 'retro'});
    });

    test('maps every pocket to the design-system pocket of the same place', () {
      for (final pocket in TablePocket.values) {
        final table = TableIllustration(
          id: 't',
          caption: 'c',
          alt: 'a',
          balls: const [],
          arrows: [
            IllustrationArrow(
              id: 'a',
              kind: IllustrationArrowKind.object,
              path: const [Point(0, 0), Point(1, 1)],
              pocket: pocket,
            ),
          ],
        );

        expect(
          IllustrationMapper.tableSpecOf(table).arrows.single.pocket!.point,
          pocket.point,
        );
      }
    });
  });
}
