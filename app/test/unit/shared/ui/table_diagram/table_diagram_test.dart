import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/billiard_cue.dart';
import 'package:billard_cfa/shared/ui/billiard_table.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/presentation_scope.dart';
import 'package:billard_cfa/shared/ui/table_diagram/diagram_timeline.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';
import 'package:billard_cfa/shared/ui/table_geometry.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../pump_ui.dart';

const _spec = TableDiagramSpec(
  id: 'full-ball',
  balls: [
    DiagramBall(
      id: 'y1',
      color: BallKind.yellow,
      at: DiagramPoint(4, 2),
      label: 'x4',
    ),
    DiagramBall(
      id: 'r1',
      color: BallKind.red,
      at: DiagramPoint(6, 1),
      role: DiagramBallRole.obstacle,
    ),
    DiagramBall(id: 'k1', color: BallKind.black, at: DiagramPoint(1, 3)),
    DiagramBall(
      id: 'w',
      color: BallKind.white,
      at: DiagramPoint(4, 3.2),
      role: DiagramBallRole.cue,
    ),
  ],
  ghosts: [
    DiagramGhost(
      id: 'g1',
      at: DiagramPoint(4, 2.2),
      role: DiagramGhostRole.impact,
      forBallId: 'w',
    ),
    DiagramGhost(
      id: 'g2',
      at: DiagramPoint(3, 3.2),
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
      path: [DiagramPoint(4, 3.2), DiagramPoint(4, 2.2)],
    ),
    DiagramArrow(
      id: 'a3',
      kind: DiagramArrowKind.indication,
      path: [DiagramPoint(6, 3), DiagramPoint(7, 0), DiagramPoint(7.5, 2)],
      bounces: [DiagramBand.top],
    ),
    DiagramArrow(
      id: 'a4',
      kind: DiagramArrowKind.indication,
      path: [DiagramPoint(6, 3)],
    ),
  ],
  zones: [
    DiagramZone(id: 'z1', from: DiagramPoint(0, 0), to: DiagramPoint(1, 1)),
  ],
  steps: [
    DiagramStep(
      cueId: 'w',
      hitId: 'y1',
      contact: ContactFraction.full,
      pocket: DiagramPocket.tm,
    ),
  ],
);

Finder _ball(BallKind kind) => find.byWidgetPredicate(
  (w) => w is BilliardBall && w.kind == kind,
  description: 'ball $kind',
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  double width = 450,
}) => pumpUi(
  tester,
  Center(
    child: SizedBox(width: width, child: child),
  ),
  locale: locale,
  theme: theme,
);

void main() {
  testWidgets('puts the text on a cloth halo when no position is free', (
    tester,
  ) async {
    // Un texte plus large que la table ne tient dans aucune des positions.
    final text = List.filled(60, 'XXXX').join(' ');
    await _pump(
      tester,
      TableDiagram(
        spec: TableDiagramSpec(
          id: 'crowded',
          balls: const [
            DiagramBall(id: 'w', color: BallKind.white, at: DiagramPoint(4, 2)),
          ],
          annotations: [
            DiagramAnnotation(
              id: 'n',
              at: const DiagramPoint(4, 2),
              text: text,
            ),
          ],
        ),
        semanticLabel: 'Crowded',
      ),
    );

    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('annotation-n')),
        matching: find.byType(DecoratedBox),
      ),
    );
    final cloth = BallColors.light.cloth.withValues(alpha: 0.85);
    expect((box.decoration as BoxDecoration).color, cloth);
  });

  testWidgets('leaves the halo off when the label has a free position', (
    tester,
  ) async {
    await _pump(
      tester,
      const TableDiagram(spec: _spec, semanticLabel: 'Full ball, 4 times'),
    );

    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('ball-label-y1')),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((box.decoration as BoxDecoration).color, isNull);
  });

  testWidgets('draws every ball of the spec on a table', (tester) async {
    await _pump(
      tester,
      const TableDiagram(spec: _spec, semanticLabel: 'Full ball, 4 times'),
    );

    expect(find.byType(BilliardTable), findsOneWidget);
    expect(find.byType(BilliardBall), findsNWidgets(4));
    expect(_ball(BallKind.yellow), findsOneWidget);
    expect(_ball(BallKind.red), findsOneWidget);
    expect(_ball(BallKind.black), findsOneWidget);
    expect(_ball(BallKind.white), findsOneWidget);
  });

  testWidgets('draws the cue ball smaller than every object ball', (
    tester,
  ) async {
    await _pump(
      tester,
      const TableDiagram(spec: _spec, semanticLabel: 'Full ball, 4 times'),
    );

    // Table de 450 px : 9 unités de 50 px. Rayons 0,103784 et 0,109838 case.
    final white = tester.getSize(_ball(BallKind.white)).width;
    expect(white, closeTo(2 * 0.103784 * 50, 1e-3));
    for (final kind in [BallKind.yellow, BallKind.red, BallKind.black]) {
      final size = tester.getSize(_ball(kind)).width;
      expect(size, closeTo(2 * 0.109838 * 50, 1e-3), reason: '$kind');
      expect(white / size, closeTo(24.0 / 25.4, 1e-6), reason: '$kind');
    }
  });

  testWidgets('puts the cue tip against the cue ball radius', (tester) async {
    await _pump(
      tester,
      const TableDiagram(spec: _spec, semanticLabel: 'Full ball, 4 times'),
    );

    // La blanche est en (4 ; 3,2) : visant (4 ; 2,2) vers le haut, la pointe
    // est sous elle à 0,103784 case = 5,1892 px (et non 0,1098).
    final tip = tester.getRect(find.byType(BilliardCue)).centerRight;
    final ball = tester.getCenter(_ball(BallKind.white));
    expect((tip - ball).distance, closeTo(5.1892, 0.05));
  });

  testWidgets('exposes the description given by the caller', (tester) async {
    await _pump(
      tester,
      const TableDiagram(spec: _spec, semanticLabel: 'Full ball, 4 times'),
    );
    expect(find.bySemanticsLabel('Full ball, 4 times'), findsOneWidget);
  });

  testWidgets('places the balls in the table coordinates', (tester) async {
    await _pump(tester, const TableDiagram(spec: _spec, semanticLabel: 'Test'));

    final table = find.byType(BilliardTable);
    final geometry = TableGeometry.fitting(tester.getSize(table));
    final origin = tester.getTopLeft(table);
    final expected = origin + geometry.toPixel(const Offset(4, 2));
    final center = tester.getCenter(_ball(BallKind.yellow));
    expect((center - expected).distance, lessThan(0.01));
  });

  testWidgets('writes the letter next to small balls, never colour alone', (
    tester,
  ) async {
    await _pump(tester, const TableDiagram(spec: _spec, semanticLabel: 'Test'));

    // 450 px de large : une bille mesure moins de 28 px, la lettre est à côté.
    expect(find.text('Y x4'), findsOneWidget);
    expect(find.text('R'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('W'), findsOneWidget);
  });

  testWidgets('uses the French letters in French', (tester) async {
    await _pump(
      tester,
      const TableDiagram(spec: _spec, semanticLabel: 'Test'),
      locale: const Locale('fr'),
    );
    expect(find.text('J x4'), findsOneWidget);
    expect(find.text('N'), findsOneWidget);
  });

  testWidgets('keeps the number of a big ball on the ball itself', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpUi(
      tester,
      const Center(
        child: SizedBox(
          width: 1600,
          child: TableDiagram(spec: _spec, semanticLabel: 'Test'),
        ),
      ),
    );
    expect(find.text('x4'), findsOneWidget);
    expect(find.text('Y x4'), findsNothing);
  });

  testWidgets('numbers the cue positions', (tester) async {
    await _pump(tester, const TableDiagram(spec: _spec, semanticLabel: 'Test'));
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('shows the cue aimed at the target before the shot', (
    tester,
  ) async {
    await _pump(tester, const TableDiagram(spec: _spec, semanticLabel: 'Test'));
    expect(find.byType(BilliardCue), findsOneWidget);
  });

  testWidgets('draws no cue when the schema has no shot', (tester) async {
    const spec = TableDiagramSpec(
      id: 'game',
      balls: [
        DiagramBall(id: 'r1', color: BallKind.red, at: DiagramPoint(0.2, 0.2)),
      ],
    );
    await _pump(tester, const TableDiagram(spec: spec, semanticLabel: 'Test'));
    expect(find.byType(BilliardCue), findsNothing);
    expect(find.byType(BilliardBall), findsOneWidget);
  });

  testWidgets('draws the frame it is given and hides pocketed balls', (
    tester,
  ) async {
    final timeline = DiagramTimeline.from(_spec);
    await _pump(
      tester,
      TableDiagram(
        spec: _spec,
        semanticLabel: 'Test',
        frame: timeline.finalFrame,
      ),
    );

    expect(_ball(BallKind.yellow), findsNothing);
    expect(find.byType(BilliardBall), findsNWidgets(3));
    expect(find.byType(BilliardCue), findsNothing);

    final table = find.byType(BilliardTable);
    final geometry = TableGeometry.fitting(tester.getSize(table));
    final expected =
        tester.getTopLeft(table) + geometry.toPixel(const Offset(4, 2.2));
    expect(
      (tester.getCenter(_ball(BallKind.white)) - expected).distance,
      lessThan(0.01),
    );
  });

  testWidgets('hides the grid and the head string on request', (tester) async {
    await _pump(
      tester,
      const TableDiagram(
        spec: _spec,
        semanticLabel: 'Test',
        showGrid: false,
        showHeadString: false,
      ),
    );
    final table = tester.widget<BilliardTable>(find.byType(BilliardTable));
    expect(table.showGrid, isFalse);
    expect(table.showHeadString, isFalse);
  });

  testWidgets('shows the grid and the head string by default', (tester) async {
    await _pump(tester, const TableDiagram(spec: _spec, semanticLabel: 'Test'));
    final table = tester.widget<BilliardTable>(find.byType(BilliardTable));
    expect(table.showGrid, isTrue);
    expect(table.showHeadString, isTrue);
  });

  testWidgets('keeps every letter at a text scale of 2 without overflow', (
    tester,
  ) async {
    for (final locale in const [Locale('en'), Locale('fr')]) {
      await pumpUi(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: const Center(
              child: SizedBox(
                width: 320,
                child: TableDiagram(spec: _spec, semanticLabel: 'Test'),
              ),
            ),
          ),
        ),
        locale: locale,
      );

      expect(tester.takeException(), isNull, reason: '$locale');
      final yellow = locale.languageCode == 'fr' ? 'J x4' : 'Y x4';
      expect(find.text(yellow), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      // Les billes ne grossissent pas avec le texte : elles restent sur le
      // repère de la table.
      final table = find.byType(BilliardTable);
      final geometry = TableGeometry.fitting(tester.getSize(table));
      final expected =
          tester.getTopLeft(table) + geometry.toPixel(const Offset(4, 2));
      expect(
        (tester.getCenter(_ball(BallKind.yellow)) - expected).distance,
        lessThan(0.01),
      );
    }
  });

  testWidgets('survives a zero-size layout', (tester) async {
    await pumpUi(
      tester,
      const Center(
        child: SizedBox.shrink(
          child: TableDiagram(spec: _spec, semanticLabel: 'Test'),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a localised error instead of throwing on a bad spec', (
    tester,
  ) async {
    const bad = TableDiagramSpec(
      id: 'bad',
      balls: [
        DiagramBall(id: 'w', color: BallKind.white, at: DiagramPoint(9, 1)),
      ],
    );
    await _pump(tester, const TableDiagram(spec: bad, semanticLabel: 'Bad'));

    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorView), findsOneWidget);
    expect(
      find.text('This exercise diagram is invalid and cannot be displayed.'),
      findsOneWidget,
    );
    expect(find.byType(BilliardTable), findsNothing);
  });

  testWidgets('the error message follows the locale', (tester) async {
    const bad = TableDiagramSpec(
      id: 'bad',
      balls: [
        DiagramBall(id: 'w', color: BallKind.white, at: DiagramPoint(9, 1)),
      ],
      steps: [DiagramStep(cueId: 'ghost')],
    );
    await _pump(
      tester,
      const TableDiagram(spec: bad, semanticLabel: 'Bad'),
      locale: const Locale('fr'),
    );
    expect(
      find.text(
        'Le schéma de cet exercice est invalide : il ne peut pas être '
        'affiché.',
      ),
      findsOneWidget,
    );
  });

  group('numbered marks', () {
    // Largeur de table pour laquelle la blanche mesure `diameter` px.
    double widthFor(double diameter) =>
        (diameter / (2 * TableGeometry.cueBallRadius)) *
        (TableGeometry.columns + 2 * TableGeometry.railWidth);

    const spec = TableDiagramSpec(
      id: 'marks',
      balls: [
        DiagramBall(id: 'r1', color: BallKind.red, at: DiagramPoint(6, 2)),
      ],
      ghosts: [
        DiagramGhost(
          id: 'g1',
          at: DiagramPoint(2, 2),
          role: DiagramGhostRole.cueStart,
          label: '3',
        ),
      ],
    );

    Future<void> pumpAt(WidgetTester tester, double diameter) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpUi(
        tester,
        Center(
          child: SizedBox(
            width: widthFor(diameter),
            child: const TableDiagram(spec: spec, semanticLabel: 'Marks'),
          ),
        ),
      );
    }

    testWidgets('writes the number inside the circle from 28 px', (
      tester,
    ) async {
      await pumpAt(tester, 28.5);

      expect(find.byKey(const ValueKey('ghost-mark-g1')), findsOneWidget);
      expect(find.byKey(const ValueKey('ghost-label-g1')), findsNothing);
    });

    testWidgets('sizes the mark circle like the white ball', (tester) async {
      await pumpAt(tester, 28.5);

      final geometry = TableGeometry.fitting(
        tester.getSize(find.byType(BilliardTable)),
      );
      final size = tester.getSize(find.byKey(const ValueKey('ghost-mark-g1')));
      expect(size.width, closeTo(geometry.ghostRadiusPx * 2, 0.01));
      expect(
        size.width,
        closeTo(geometry.radiusPxOf(BallKind.white) * 2, 0.01),
      );
    });

    testWidgets('writes the number beside the circle under 28 px', (
      tester,
    ) async {
      await pumpAt(tester, 27.5);

      expect(find.byKey(const ValueKey('ghost-mark-g1')), findsNothing);
      expect(find.byKey(const ValueKey('ghost-label-g1')), findsOneWidget);
    });
  });

  group('inset', () {
    const spec = TableDiagramSpec(
      id: 'inset',
      balls: [
        DiagramBall(id: 'w', color: BallKind.white, at: DiagramPoint(2, 3)),
        DiagramBall(id: 'r1', color: BallKind.red, at: DiagramPoint(4, 2)),
      ],
      inset: DiagramInset(contact: ContactFraction.half),
    );

    testWidgets('shows the ball quantity label in a corner', (tester) async {
      await _pump(
        tester,
        const TableDiagram(spec: spec, semanticLabel: 'Inset'),
      );

      expect(find.byKey(const ValueKey('contact-inset')), findsOneWidget);
      expect(find.text('Half ball'), findsOneWidget);
    });

    testWidgets('moves to a free corner when a ball sits in the first', (
      tester,
    ) async {
      const crowded = TableDiagramSpec(
        id: 'inset-crowded',
        balls: [
          DiagramBall(id: 'r1', color: BallKind.red, at: DiagramPoint(7, 3.4)),
        ],
        inset: DiagramInset(contact: ContactFraction.half),
      );
      await _pump(
        tester,
        const TableDiagram(spec: crowded, semanticLabel: 'Inset'),
        width: 900,
      );

      final table = tester.getRect(find.byType(BilliardTable));
      final inset = tester.getRect(find.byKey(const ValueKey('contact-inset')));
      expect(inset.center.dx, lessThan(table.center.dx));
      expect(table.contains(inset.center), isTrue);
    });

    testWidgets('goes under the table when no place on it is free', (
      tester,
    ) async {
      // Quatre traits sur toute la largeur, espacés d'une case : un médaillon
      // posé sur la table en croise forcément un.
      final walls = TableDiagramSpec(
        id: 'inset-walls',
        balls: const [
          DiagramBall(id: 'w', color: BallKind.white, at: DiagramPoint(4, 2)),
        ],
        arrows: [
          for (final y in [0.5, 1.5, 2.5, 3.5])
            DiagramArrow(
              id: 'a$y',
              kind: DiagramArrowKind.indication,
              path: [DiagramPoint(0, y), DiagramPoint(8, y)],
            ),
        ],
        inset: const DiagramInset(contact: ContactFraction.half),
      );
      await _pump(
        tester,
        TableDiagram(spec: walls, semanticLabel: 'Inset'),
        width: 900,
      );

      final table = tester.getRect(find.byType(BilliardTable));
      final inset = tester.getRect(find.byKey(const ValueKey('contact-inset')));
      expect(inset.top, greaterThanOrEqualTo(table.bottom));
      expect(find.text('Half ball'), findsOneWidget);
    });

    testWidgets('goes under a table too small for its caption', (tester) async {
      await _pump(
        tester,
        const TableDiagram(
          spec: TableDiagramSpec(
            id: 'inset-small',
            balls: [
              DiagramBall(
                id: 'w',
                color: BallKind.white,
                at: DiagramPoint(1, 1),
              ),
            ],
            inset: DiagramInset(contact: ContactFraction.threeQuarter),
          ),
          semanticLabel: 'Inset',
        ),
        width: 300,
      );

      final table = tester.getRect(find.byType(BilliardTable));
      final inset = tester.getRect(find.byKey(const ValueKey('contact-inset')));
      expect(inset.top, greaterThanOrEqualTo(table.bottom));
      expect(inset.right, lessThanOrEqualTo(table.right));
      // La description du schéma reste exactement celle de l'appelant.
      expect(find.bySemanticsLabel('Inset'), findsOneWidget);
    });

    testWidgets('keeps the caption on one line', (tester) async {
      await _pump(
        tester,
        const TableDiagram(spec: spec, semanticLabel: 'Inset'),
        width: 900,
      );

      // Une seule ligne de bodyMedium (14 px, interligne 1,43 ≈ 20 px).
      expect(tester.getSize(find.text('Half ball')).height, lessThan(24));
    });
  });

  group('presentation label size', () {
    const spec = TableDiagramSpec(
      id: 'size',
      balls: [
        DiagramBall(
          id: 'r1',
          color: BallKind.red,
          at: DiagramPoint(4, 2),
          label: 'x4',
        ),
      ],
    );

    double labelSize(WidgetTester tester) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(const ValueKey('ball-label-r1')),
          matching: find.byType(RichText),
        ),
      );
      return paragraph.textScaler.scale(paragraph.text.style!.fontSize!);
    }

    testWidgets('raises the labels to 16 px in presentation', (tester) async {
      await _pump(
        tester,
        const PresentationScope(
          scale: 1,
          child: TableDiagram(spec: spec, semanticLabel: 'Size'),
        ),
      );

      expect(labelSize(tester), greaterThanOrEqualTo(16));
    });

    testWidgets('keeps the label size outside presentation', (tester) async {
      await _pump(
        tester,
        const TableDiagram(spec: spec, semanticLabel: 'Size'),
      );

      expect(labelSize(tester), lessThan(16));
    });
  });
}
