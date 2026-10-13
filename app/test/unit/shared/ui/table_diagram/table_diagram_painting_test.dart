import 'dart:ui' as ui;

import 'package:billard_cfa/shared/ui/billiard_table.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';
import 'package:billard_cfa/shared/ui/table_geometry.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../pump_ui.dart';

/// Ce que peint le schéma, vérifié sur les appels de peinture (positions en
/// pixels calculées avec `TableGeometry`, jamais avec le code testé).

/// Un appel de peinture enregistré.
class _Call {
  const _Call(this.name, this.args);

  final Symbol name;
  final List<dynamic> args;

  Paint get paint => args.last as Paint;
  ui.Path get path => args.first as ui.Path;
}

Finder _painter(String type) => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter.runtimeType.toString() == type,
  description: type,
);

/// Appels de peinture du `CustomPaint` dont le peintre s'appelle [type].
List<_Call> _calls(WidgetTester tester, String type) {
  final calls = <_Call>[];
  expect(
    tester.renderObject(_painter(type)),
    paints..everything((name, args) {
      calls.add(_Call(name, args));
      return true;
    }),
  );
  return calls;
}

List<_Call> _guides(WidgetTester tester, [Symbol? name]) => [
  for (final c in _calls(tester, '_GuidePainter'))
    if (name == null || c.name == name) c,
];

double _length(ui.Path path) =>
    path.computeMetrics().fold<double>(0, (sum, m) => sum + m.length);

Future<TableGeometry> _pump(
  WidgetTester tester,
  TableDiagramSpec spec, {
  ThemeData? theme,
  bool showHeadString = true,
}) async {
  await pumpUi(
    tester,
    Center(
      child: SizedBox(
        width: 450,
        child: TableDiagram(
          spec: spec,
          semanticLabel: 'Test',
          showHeadString: showHeadString,
        ),
      ),
    ),
    theme: theme,
  );
  // Le changement de thème est animé (`AnimatedTheme`).
  await tester.pumpAndSettle();
  return TableGeometry.fitting(tester.getSize(find.byType(BilliardTable)));
}

TableDiagramSpec _arrows(List<DiagramArrow> arrows) =>
    TableDiagramSpec(id: 'arrows', balls: const [], arrows: arrows);

DiagramArrow _arrow(
  DiagramArrowKind kind,
  List<DiagramPoint> path, {
  List<DiagramBand> bounces = const [],
}) => DiagramArrow(id: 'a', kind: kind, path: path, bounces: bounces);

/// Point construit à l'exécution (les littéraux `const` ne passent pas par le
/// constructeur).
DiagramPoint _p(double x, double y) => DiagramPoint(x, y);

/// Chemins pleins (têtes de flèche) du peintre des guides.
Iterable<_Call> _fills(WidgetTester tester) => _guides(
  tester,
  #drawPath,
).where((c) => c.paint.style == PaintingStyle.fill);

/// Chemins tracés (hampes, tirets, cercles creux).
Iterable<_Call> _strokes(WidgetTester tester) => _guides(
  tester,
  #drawPath,
).where((c) => c.paint.style == PaintingStyle.stroke);

void main() {
  group('arrows', () {
    // Trois traits : plein (bille touchée), tirets (blanche), points
    // (indication) ; une même ligne de (1 ; 2) à (5 ; 2), soit 4 cases.
    const line = [DiagramPoint(1, 2), DiagramPoint(5, 2)];

    Future<List<double>> segments(
      WidgetTester tester,
      DiagramArrowKind kind,
    ) async {
      final g = await _pump(tester, _arrows([_arrow(kind, line)]));
      expect(g.unit, 50);
      return [for (final c in _strokes(tester)) _length(c.path)];
    }

    testWidgets('an object arrow is one solid stroke of the whole length', (
      tester,
    ) async {
      final lengths = await segments(tester, DiagramArrowKind.object);
      expect(lengths, hasLength(1));
      expect(lengths.single, closeTo(4 * 50, 1e-6));
    });

    testWidgets('a cue arrow is made of dashes, an indication of dots', (
      tester,
    ) async {
      final dashes = await segments(tester, DiagramArrowKind.cue);
      final dots = await segments(tester, DiagramArrowKind.indication);

      expect(dashes.length, greaterThan(5));
      expect(dots.length, greaterThan(dashes.length));
      final longestDash = dashes.reduce((a, b) => a > b ? a : b);
      final longestDot = dots.reduce((a, b) => a > b ? a : b);
      expect(longestDash, lessThan(4 * 50 / 5));
      expect(longestDot, lessThan(longestDash));
      // Les traits suivent la ligne : la somme des tirets reste sous 4 cases.
      expect(dashes.fold<double>(0, (a, b) => a + b), lessThan(4 * 50));
    });

    for (final kind in DiagramArrowKind.values) {
      testWidgets('a $kind arrow ends on a head at its last point', (
        tester,
      ) async {
        final g = await _pump(tester, _arrows([_arrow(kind, line)]));
        final tip = g.toPixel(const Offset(5, 2));

        final heads = _fills(tester).toList();
        expect(heads, hasLength(1));
        final head = heads.single.path;
        // Cinq pixels avant la pointe : dedans ; cinq après : dehors.
        expect(head.contains(tip - const Offset(5, 0)), isTrue);
        expect(head.contains(tip + const Offset(5, 0)), isFalse);
        expect(head.contains(tip - const Offset(5, 20)), isFalse);
      });
    }

    testWidgets('the head follows the last segment of a bent arrow', (
      tester,
    ) async {
      final g = await _pump(
        tester,
        _arrows([
          _arrow(
            DiagramArrowKind.indication,
            const [
              DiagramPoint(6, 3),
              DiagramPoint(7, 0),
              DiagramPoint(7.5, 2),
            ],
            bounces: const [DiagramBand.top],
          ),
        ]),
      );
      final tip = g.toPixel(const Offset(7.5, 2));
      final back = g.toPixel(const Offset(7, 0));
      final direction = (tip - back) / (tip - back).distance;

      final head = _fills(tester).single.path;
      expect(head.contains(tip - direction * 5), isTrue);
      expect(head.contains(tip + direction * 5), isFalse);
    });

    testWidgets('a repeated last point does not turn the head around', (
      tester,
    ) async {
      final g = await _pump(
        tester,
        _arrows([
          _arrow(DiagramArrowKind.object, const [
            DiagramPoint(1, 2),
            DiagramPoint(5, 2),
            DiagramPoint(5, 2),
          ]),
        ]),
      );
      final tip = g.toPixel(const Offset(5, 2));
      final head = _fills(tester).single.path;
      expect(head.contains(tip - const Offset(5, 0)), isTrue);
      expect(head.contains(tip + const Offset(5, 0)), isFalse);
    });

    testWidgets('an arrow without any length has no head and no error', (
      tester,
    ) async {
      await _pump(
        tester,
        _arrows([
          _arrow(DiagramArrowKind.object, const [
            DiagramPoint(2, 2),
            DiagramPoint(2, 2),
          ]),
        ]),
      );
      expect(tester.takeException(), isNull);
      expect(_fills(tester), isEmpty);
    });

    testWidgets('an arrow of a single point draws nothing', (tester) async {
      await _pump(
        tester,
        _arrows([
          _arrow(DiagramArrowKind.indication, const [DiagramPoint(6, 3)]),
        ]),
      );
      expect(_guides(tester).where((c) => c.name == #drawPath), isEmpty);
    });
  });

  group('rebound marks', () {
    testWidgets('a rebound draws a circle on the rebound point only', (
      tester,
    ) async {
      final g = await _pump(
        tester,
        _arrows([
          _arrow(
            DiagramArrowKind.cue,
            const [
              DiagramPoint(1, 3),
              DiagramPoint(7, 0),
              DiagramPoint(7.5, 2),
            ],
            bounces: const [DiagramBand.top],
          ),
        ]),
      );
      final circles = _guides(tester, #drawCircle);
      expect(circles, hasLength(1));
      expect(circles.single.args[0], g.toPixel(const Offset(7, 0)));
      expect(circles.single.args[1] as double, greaterThan(0));
    });

    testWidgets('two rebounds draw two circles, in path order', (tester) async {
      final g = await _pump(
        tester,
        _arrows([
          _arrow(
            DiagramArrowKind.cue,
            const [
              DiagramPoint(0, 4),
              DiagramPoint(3, 0),
              DiagramPoint(6, 4),
              DiagramPoint(6, 1),
            ],
            bounces: const [DiagramBand.top, DiagramBand.bottom],
          ),
        ]),
      );
      final circles = _guides(tester, #drawCircle);
      expect(circles.map((c) => c.args[0]), [
        g.toPixel(const Offset(3, 0)),
        g.toPixel(const Offset(6, 4)),
      ]);
    });

    testWidgets('a count of bands that does not fit the path draws none', (
      tester,
    ) async {
      await _pump(
        tester,
        _arrows([
          _arrow(
            DiagramArrowKind.cue,
            const [
              DiagramPoint(0, 4),
              DiagramPoint(3, 0),
              DiagramPoint(6, 4),
              DiagramPoint(6, 1),
            ],
            bounces: const [DiagramBand.top],
          ),
        ]),
      );
      expect(_guides(tester, #drawCircle), isEmpty);
    });
  });

  group('zones and hollow circles', () {
    testWidgets('a zone is a filled and outlined rectangle of its cells', (
      tester,
    ) async {
      final g = await _pump(
        tester,
        const TableDiagramSpec(
          id: 'zone',
          balls: [],
          zones: [
            DiagramZone(
              id: 'z',
              from: DiagramPoint(0, 0),
              to: DiagramPoint(1, 1),
            ),
          ],
        ),
      );
      final expected = Rect.fromPoints(
        g.toPixel(Offset.zero),
        g.toPixel(const Offset(1, 1)),
      );
      expect(expected.size, const Size(50, 50));

      final rects = _guides(tester, #drawRect);
      expect(rects, hasLength(2));
      expect(rects.every((c) => c.args.first == expected), isTrue);
      expect(rects.first.paint.style, PaintingStyle.fill);
      expect(
        rects.first.paint.color.toARGB32(),
        TableColors.light.headString.withValues(alpha: 0.18).toARGB32(),
      );
      expect(rects.last.paint.style, PaintingStyle.stroke);
    });

    testWidgets('a zone given by its far corner first is the same rectangle', (
      tester,
    ) async {
      final g = await _pump(
        tester,
        TableDiagramSpec(
          id: 'zone',
          balls: const [],
          zones: [DiagramZone(id: 'z', from: _p(3, 2), to: _p(1, 1))],
        ),
      );
      final rect = _guides(tester, #drawRect).first.args.first as Rect;
      expect(rect.topLeft, g.toPixel(const Offset(1, 1)));
      expect(rect.bottomRight, g.toPixel(const Offset(3, 2)));
    });

    for (final role in DiagramGhostRole.values) {
      testWidgets('a $role circle is an outline around its position', (
        tester,
      ) async {
        final g = await _pump(
          tester,
          TableDiagramSpec(
            id: 'ghost',
            balls: const [],
            ghosts: [
              DiagramGhost(id: 'g', at: const DiagramPoint(3, 2), role: role),
            ],
          ),
        );
        final center = g.toPixel(const Offset(3, 2));
        final radius = g.ballRadiusPx;

        expect(_guides(tester, #drawCircle), isEmpty);
        expect(_fills(tester), isEmpty);
        final strokes = _strokes(tester).toList();
        expect(strokes, isNotEmpty);
        var union = strokes.first.path.getBounds();
        for (final c in strokes) {
          final b = c.path.getBounds();
          union = union.expandToInclude(b);
          expect(
            Rect.fromCircle(center: center, radius: radius).inflate(0.01),
            predicate<Rect>(
              (r) =>
                  r.contains(b.topLeft) &&
                  r.contains(b.bottomRight - const Offset(0.01, 0.01)),
            ),
          );
        }
        // Les tirets font le tour complet du cercle.
        expect(union.center.dx, closeTo(center.dx, 0.5));
        expect(union.center.dy, closeTo(center.dy, 0.5));
        expect(union.width, closeTo(2 * radius, 0.5));
        expect(union.height, closeTo(2 * radius, 0.5));
      });
    }
  });

  group('table markings', () {
    testWidgets('draws the head string at x = 2 across the table', (
      tester,
    ) async {
      final g = await _pump(tester, _arrows(const []));
      final lines = _calls(tester, '_TablePainter').where(
        (c) =>
            c.name == #drawLine &&
            c.args[0] == g.toPixel(const Offset(2, 0)) &&
            c.args[1] == g.toPixel(const Offset(2, 4)),
      );
      expect(lines, hasLength(1));
      expect(
        lines.single.paint.color.toARGB32(),
        TableColors.light.headString.toARGB32(),
      );
    });

    testWidgets('hides the head string on request', (tester) async {
      final g = await _pump(tester, _arrows(const []), showHeadString: false);
      final lines = _calls(tester, '_TablePainter').where(
        (c) =>
            c.name == #drawLine &&
            c.args[0] == g.toPixel(const Offset(2, 0)) &&
            c.args[1] == g.toPixel(const Offset(2, 4)),
      );
      expect(lines, isEmpty);
    });
  });

  group('dark theme', () {
    const spec = TableDiagramSpec(
      id: 'dark',
      balls: [
        DiagramBall(id: 'y1', color: BallKind.yellow, at: DiagramPoint(4, 2)),
      ],
      arrows: [
        DiagramArrow(
          id: 'a',
          kind: DiagramArrowKind.object,
          ballId: 'y1',
          path: [DiagramPoint(4, 2), DiagramPoint(4, 0)],
        ),
      ],
    );

    int argb(Color c) => c.toARGB32();

    Iterable<_Call> tableCalls(WidgetTester tester, Symbol name) =>
        _calls(tester, '_TablePainter').where((c) => c.name == name);

    testWidgets('paints the cloth, the rails and the ink of the theme', (
      tester,
    ) async {
      // Les jeux de couleurs diffèrent : le test distingue bien les thèmes.
      expect(BallColors.dark.cloth, isNot(BallColors.light.cloth));
      expect(TableColors.dark.rail, isNot(TableColors.light.rail));
      expect(TableColors.dark.headString, isNot(TableColors.light.headString));

      final g = await _pump(tester, spec, theme: AppTheme.dark());
      expect(
        argb(tableCalls(tester, #drawRRect).first.paint.color),
        argb(TableColors.dark.rail),
      );
      final cloth = tableCalls(
        tester,
        #drawRect,
      ).where((c) => c.args.first == g.surface);
      expect(argb(cloth.single.paint.color), argb(BallColors.dark.cloth));
      for (final c in _strokes(tester)) {
        expect(argb(c.paint.color), argb(TableColors.dark.headString));
      }
      expect(
        argb(_fills(tester).single.paint.color),
        argb(TableColors.dark.headString),
      );
    });

    testWidgets('paints the light theme with the light colours', (
      tester,
    ) async {
      final g = await _pump(tester, spec);
      expect(
        argb(tableCalls(tester, #drawRRect).first.paint.color),
        argb(TableColors.light.rail),
      );
      final cloth = tableCalls(
        tester,
        #drawRect,
      ).where((c) => c.args.first == g.surface);
      expect(argb(cloth.single.paint.color), argb(BallColors.light.cloth));
      for (final c in _strokes(tester)) {
        expect(argb(c.paint.color), argb(TableColors.light.headString));
      }
    });

    testWidgets('outlines the ball with the pocket colour of the theme', (
      tester,
    ) async {
      Future<int> outline(ThemeData theme) async {
        await _pump(tester, spec, theme: theme);
        final outlines = _calls(tester, '_BallPainter').where(
          (c) => c.name == #drawCircle && c.paint.style == PaintingStyle.stroke,
        );
        return argb(outlines.single.paint.color);
      }

      expect(
        await outline(AppTheme.dark()),
        argb(TableColors.dark.pocket.withValues(alpha: 0.55)),
      );
      expect(
        await outline(AppTheme.light()),
        argb(TableColors.light.pocket.withValues(alpha: 0.55)),
      );
    });

    testWidgets('keeps the yellow of the ball in both themes', (tester) async {
      // Même jaune en clair et en sombre (jeton volontairement partagé) : la
      // bille reste reconnaissable ; seul le tapis qui la porte change.
      expect(BallColors.dark.yellow, BallColors.light.yellow);
      await _pump(tester, spec, theme: AppTheme.dark());
      final theme = Theme.of(tester.element(find.byType(TableDiagram)));
      expect(theme.extension<BallColors>(), BallColors.dark);
      expect(theme.extension<TableColors>(), TableColors.dark);
    });
  });

  group('repaint', () {
    CustomPainter guide(WidgetTester tester) =>
        tester.widget<CustomPaint>(_painter('_GuidePainter')).painter!;

    testWidgets('repaints when the spec, the size or the ink changes', (
      tester,
    ) async {
      const empty = TableDiagramSpec(id: 'empty', balls: []);
      await _pump(tester, empty);
      final before = guide(tester);

      await _pump(tester, empty);
      expect(guide(tester).shouldRepaint(before), isFalse);

      await _pump(
        tester,
        _arrows([
          _arrow(DiagramArrowKind.object, const [
            DiagramPoint(1, 1),
            DiagramPoint(2, 1),
          ]),
        ]),
      );
      expect(guide(tester).shouldRepaint(before), isTrue);

      await _pump(tester, empty, theme: AppTheme.dark());
      expect(guide(tester).shouldRepaint(before), isTrue);

      await pumpUi(
        tester,
        const Center(
          child: SizedBox(
            width: 300,
            child: TableDiagram(spec: empty, semanticLabel: 'Test'),
          ),
        ),
      );
      expect(guide(tester).shouldRepaint(before), isTrue);
    });
  });

  group('aim arrows', () {
    const line = [DiagramPoint(1, 2), DiagramPoint(5, 2)];

    testWidgets('an aim arrow alternates long dashes and short dots', (
      tester,
    ) async {
      final g = await _pump(
        tester,
        _arrows([_arrow(DiagramArrowKind.aim, line)]),
      );
      expect(g.unit, 50);
      final lengths = [for (final c in _strokes(tester)) _length(c.path)];

      // Motif : trait de 0,3 case, blanc 0,07, point de 0,03, blanc 0,07.
      final long = lengths.where((l) => (l - 15).abs() < 0.5).length;
      final dots = lengths.where((l) => (l - 1.5).abs() < 0.5).length;
      expect(long, greaterThanOrEqualTo(8));
      expect(dots, greaterThanOrEqualTo(8));
      // Seul le dernier trait peut être tronqué par la fin de la ligne.
      expect(lengths.length - long - dots, lessThanOrEqualTo(1));
    });

    testWidgets('a cue arrow keeps one dash length, unlike an aim arrow', (
      tester,
    ) async {
      await _pump(tester, _arrows([_arrow(DiagramArrowKind.cue, line)]));
      final lengths = {
        for (final c in _strokes(tester)) _length(c.path).round(),
      };

      expect(lengths.length, lessThanOrEqualTo(2));
      expect(lengths, isNot(contains(2)));
    });
  });

  group('annotations', () {
    testWidgets('writes the text of an annotation on the table', (
      tester,
    ) async {
      await _pump(
        tester,
        const TableDiagramSpec(
          id: 'a',
          balls: [],
          annotations: [
            DiagramAnnotation(id: 'n', at: DiagramPoint(4, 2), text: '90°'),
          ],
        ),
      );

      expect(find.text('90°'), findsOneWidget);
    });

    testWidgets('puts the text next to its point, not at the origin', (
      tester,
    ) async {
      final g = await _pump(
        tester,
        const TableDiagramSpec(
          id: 'a',
          balls: [],
          annotations: [
            DiagramAnnotation(id: 'n', at: DiagramPoint(6, 3), text: 'Zone'),
          ],
        ),
      );

      final at =
          tester.getTopLeft(find.byType(BilliardTable)) +
          g.toPixel(const Offset(6, 3));
      final box = tester.getRect(find.text('Zone'));
      expect((box.center - at).distance, lessThan(g.unit * 1.5));
    });
  });
}
