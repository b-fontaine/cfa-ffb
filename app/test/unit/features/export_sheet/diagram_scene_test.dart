import 'dart:math' show Point, Rectangle;

import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/features/export_sheet/domain/diagram_scene.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixed_text_measure.dart';

const _measure = FixedTextMeasure();

// Une table de 400 points de large : une case fait 50 points.
const _x = 20.0;
const _y = 30.0;
const _width = 400.0;
const _cell = 50.0;

DiagramDrawing _draw(DiagramTable table) =>
    drawDiagram(table, x: _x, y: _y, width: _width, measure: _measure);

Iterable<T> _tagged<T extends PrintItem>(DiagramDrawing d, String tag) =>
    d.items.whereType<T>().where((i) => i.tag == tag);

TableBall _ball(
  String id,
  TableBallColor color,
  double x,
  double y, {
  TableBallRole? role,
  String? label,
  int? order,
}) => TableBall(
  id: id,
  color: color,
  at: Point(x, y),
  role: role,
  label: label,
  order: order,
);

void main() {
  group('table', () {
    test('is twice as wide as high, like the 8 by 4 cells of the schemas', () {
      final drawing = _draw(const DiagramTable(balls: []));

      expect(drawing.height, _width / 2);
    });

    test('draws the cushion rectangle at the requested place', () {
      final drawing = _draw(const DiagramTable(balls: []));
      final rect = _tagged<PrintRect>(drawing, 'table').single;

      expect([rect.x, rect.y, rect.width, rect.height], [_x, _y, _width, 200]);
    });

    test(
      'draws six pockets at the corners and the middle of the long sides',
      () {
        final drawing = _draw(const DiagramTable(balls: []));
        final centers = _tagged<PrintCircle>(
          drawing,
          'pocket',
        ).map((c) => (c.center.x, c.center.y)).toSet();

        expect(centers, {
          (_x, _y),
          (_x + 4 * _cell, _y),
          (_x + 8 * _cell, _y),
          (_x, _y + 4 * _cell),
          (_x + 4 * _cell, _y + 4 * _cell),
          (_x + 8 * _cell, _y + 4 * _cell),
        });
      },
    );

    test('sizes the pockets from the opening of the real pockets', () {
      final drawing = _draw(const DiagramTable(balls: []));

      for (final pocket in _tagged<PrintCircle>(drawing, 'pocket')) {
        expect(
          pocket.radius,
          closeTo(BlackballDimensions.pocketOpening / 2 * _cell, 1e-9),
        );
      }
    });

    test(
      'draws the head string at 1.6 cells, from one cushion to the other',
      () {
        final drawing = _draw(const DiagramTable(balls: []));
        final line = _tagged<PrintLine>(drawing, 'head-string').single;

        expect(
          line.from.x,
          closeTo(_x + BlackballDimensions.headString * _cell, 1e-9),
        );
        expect(line.from.x, closeTo(_x + 1.6 * _cell, 1e-9));
        expect(line.to.x, line.from.x);
        expect([line.from.y, line.to.y], [_y, _y + 200]);
      },
    );

    test('has no ball, no arrow and no label when the table is empty', () {
      final drawing = _draw(const DiagramTable(balls: []));

      expect(_tagged(drawing, 'ball'), isEmpty);
      expect(_tagged(drawing, 'arrow'), isEmpty);
      expect(_tagged(drawing, 'label'), isEmpty);
    });
  });

  group('balls', () {
    test('are placed in cells and scaled to the real diameters', () {
      final drawing = _draw(
        DiagramTable(
          balls: [
            _ball('w', TableBallColor.white, 2, 1, role: TableBallRole.cue),
            _ball('r', TableBallColor.red, 6.5, 3.25),
          ],
        ),
      );
      final balls = _tagged<PrintCircle>(drawing, 'ball').toList();

      expect(balls, hasLength(2));
      expect(balls[0].center, const Point(_x + 100.0, _y + 50.0));
      expect(
        balls[0].radius,
        closeTo(BlackballDimensions.cueBallRadius * _cell, 1e-9),
      );
      expect(balls[1].center, const Point(_x + 325.0, _y + 162.5));
      expect(
        balls[1].radius,
        closeTo(BlackballDimensions.objectBallRadius * _cell, 1e-9),
      );
      expect(balls[0].radius, lessThan(balls[1].radius));
    });

    test(
      'carry their letter, so that colour never carries the meaning alone',
      () {
        final drawing = _draw(
          DiagramTable(
            balls: [
              _ball('w', TableBallColor.white, 1, 1, role: TableBallRole.cue),
              _ball('r', TableBallColor.red, 3, 1),
              _ball('y', TableBallColor.yellow, 5, 1),
              _ball('n', TableBallColor.black, 7, 1),
            ],
          ),
        );
        final letters = _tagged<PrintText>(drawing, 'ball-letter').toList();

        expect(letters.map((t) => t.text), ['B', 'R', 'J', 'N']);
        for (final (i, letter) in letters.indexed) {
          final ball = _tagged<PrintCircle>(drawing, 'ball').elementAt(i);
          expect(letter.align, PrintAlign.center);
          expect(letter.x, ball.center.x);
          expect(letter.y, greaterThan(ball.center.y));
          expect(letter.y, lessThan(ball.center.y + ball.radius));
        }
      },
    );

    test('print the letter of a black ball in white, on a black ball', () {
      final drawing = _draw(
        DiagramTable(balls: [_ball('n', TableBallColor.black, 4, 2)]),
      );

      expect(
        _tagged<PrintCircle>(drawing, 'ball').single.fill,
        PrintShade.black,
      );
      expect(
        _tagged<PrintText>(drawing, 'ball-letter').single.shade,
        PrintShade.white,
      );
    });

    test('shade a red ball and leave a yellow one white', () {
      final drawing = _draw(
        DiagramTable(
          balls: [
            _ball('r', TableBallColor.red, 2, 2),
            _ball('y', TableBallColor.yellow, 4, 2),
          ],
        ),
      );
      final fills = _tagged<PrintCircle>(drawing, 'ball').map((c) => c.fill);

      expect(fills, [PrintShade.lightGray, PrintShade.white]);
    });

    test('draw an obstacle with a dashed outline', () {
      final drawing = _draw(
        DiagramTable(
          balls: [
            _ball('r', TableBallColor.red, 2, 2, role: TableBallRole.obstacle),
          ],
        ),
      );

      expect(_tagged<PrintCircle>(drawing, 'ball').single.dash, isNotEmpty);
    });

    test('write the shot order next to the ball', () {
      final drawing = _draw(
        DiagramTable(balls: [_ball('r', TableBallColor.red, 3, 2, order: 2)]),
      );
      final order = _tagged<PrintText>(drawing, 'ball-order').single;

      expect(order.text, '2');
    });
  });

  group('ghosts, arrows and zones', () {
    test('draw a hollow dashed circle at the size of the cue ball', () {
      final drawing = _draw(
        const DiagramTable(
          balls: [],
          ghosts: [
            TableGhost(id: 'g', at: Point(3, 2), role: TableGhostRole.impact),
          ],
        ),
      );
      final ghost = _tagged<PrintCircle>(drawing, 'ghost').single;

      expect(ghost.fill, isNull);
      expect(ghost.stroke, PrintShade.black);
      expect(ghost.dash, isNotEmpty);
      expect(ghost.center, const Point(_x + 150.0, _y + 100.0));
      expect(
        ghost.radius,
        closeTo(BlackballDimensions.cueBallRadius * _cell, 1e-9),
      );
    });

    DiagramTable arrows(List<TableArrow> list) =>
        DiagramTable(balls: const [], arrows: list);

    TableArrow arrow(
      String id,
      TableArrowKind kind,
      List<Point<double>> path,
    ) => TableArrow(id: id, kind: kind, path: path);

    test('use a plain, dashed and dotted line by kind of arrow', () {
      final drawing = _draw(
        arrows([
          arrow('o', TableArrowKind.object, const [Point(1, 1), Point(3, 1)]),
          arrow('c', TableArrowKind.cue, const [Point(1, 2), Point(3, 2)]),
          arrow('i', TableArrowKind.indication, const [
            Point(1, 3),
            Point(3, 3),
          ]),
        ]),
      );
      final lines = _tagged<PrintPolyline>(drawing, 'arrow').toList();

      expect(lines, hasLength(3));
      expect(lines[0].dash, isEmpty);
      expect(lines[1].dash, isNotEmpty);
      expect(lines[2].dash, isNotEmpty);
      expect(lines[1].dash, isNot(lines[2].dash));
    });

    test('scale the path in cells and put a head at its end', () {
      final drawing = _draw(
        arrows([
          arrow('o', TableArrowKind.object, const [Point(1, 1), Point(3, 1)]),
        ]),
      );
      final line = _tagged<PrintPolyline>(drawing, 'arrow').single;
      final head = _tagged<PrintPolygon>(drawing, 'arrow-head').single;

      expect(line.points, [
        const Point(_x + 50.0, _y + 50.0),
        const Point(_x + 150.0, _y + 50.0),
      ]);
      expect(head.points, hasLength(3));
      // La pointe est au bout du tracé.
      expect(head.points.first, const Point(_x + 150.0, _y + 50.0));
    });

    test('put no head on a path of a single point and do not fail', () {
      final drawing = _draw(
        arrows([
          arrow('o', TableArrowKind.object, const [Point(1, 1)]),
        ]),
      );

      expect(_tagged<PrintPolygon>(drawing, 'arrow-head'), isEmpty);
    });

    test('keep the bounce points of a path', () {
      final drawing = _draw(
        arrows([
          arrow('c', TableArrowKind.cue, const [
            Point(1, 1),
            Point(4, 0),
            Point(7, 3),
          ]),
        ]),
      );

      expect(
        _tagged<PrintPolyline>(drawing, 'arrow').single.points,
        hasLength(3),
      );
    });

    test(
      'draw a zone as a dashed rectangle whatever the order of its corners',
      () {
        final drawing = _draw(
          const DiagramTable(
            balls: [],
            zones: [TableZone(id: 'z', from: Point(5, 3), to: Point(2, 1))],
          ),
        );
        final zone = _tagged<PrintRect>(drawing, 'zone').single;

        expect(
          [zone.x, zone.y, zone.width, zone.height],
          [_x + 100.0, _y + 50.0, 150.0, 100.0],
        );
        expect(zone.dash, isNotEmpty);
        expect(zone.fill, isNull);
      },
    );
  });

  group('labels', () {
    test('are written next to what they name, inside the table', () {
      final drawing = _draw(
        DiagramTable(
          balls: [_ball('r', TableBallColor.red, 4, 2, label: 'x4')],
          zones: [
            const TableZone(
              id: 'z',
              from: Point(5, 1),
              to: Point(7, 3),
              label: 'Zone',
            ),
          ],
        ),
      );
      final labels = _tagged<PrintText>(drawing, 'label').toList();

      expect(labels.map((t) => t.text), ['x4', 'Zone']);
      for (final label in labels) {
        final box = _box(label);
        expect(box.left, greaterThanOrEqualTo(_x));
        expect(box.right, lessThanOrEqualTo(_x + _width));
        expect(box.top, greaterThanOrEqualTo(_y));
        expect(box.bottom, lessThanOrEqualTo(_y + 200));
      }
    });

    test('never overlap each other or a ball, even on a crowded table', () {
      final balls = [
        for (var i = 0; i < 6; i++)
          _ball('b$i', TableBallColor.red, 3 + i * 0.35, 2, label: 'repère $i'),
      ];
      final drawing = _draw(DiagramTable(balls: balls));
      final labels = _tagged<PrintText>(drawing, 'label').map(_box).toList();
      final circles = _tagged<PrintCircle>(drawing, 'ball').toList();

      expect(labels, hasLength(6));
      for (final (i, a) in labels.indexed) {
        for (final b in labels.skip(i + 1)) {
          expect(a.intersects(b), isFalse, reason: '$a / $b');
        }
        for (final ball in circles) {
          final box = Rectangle<double>(
            ball.center.x - ball.radius,
            ball.center.y - ball.radius,
            2 * ball.radius,
            2 * ball.radius,
          );
          expect(a.intersects(box), isFalse, reason: '$a / $box');
        }
      }
    });

    test('stay inside the table for a ball against the cushion', () {
      final drawing = _draw(
        DiagramTable(
          balls: [
            _ball('r', TableBallColor.red, 7.95, 2, label: 'repère long'),
            _ball('w', TableBallColor.white, 0.05, 2, label: 'départ'),
          ],
        ),
      );

      for (final label in _tagged<PrintText>(drawing, 'label')) {
        final box = _box(label);
        expect(box.left, greaterThanOrEqualTo(_x), reason: label.text);
        expect(box.right, lessThanOrEqualTo(_x + _width), reason: label.text);
        expect(box.top, greaterThanOrEqualTo(_y), reason: label.text);
        expect(box.bottom, lessThanOrEqualTo(_y + 200), reason: label.text);
      }
    });

    test('name an arrow in the middle of its path', () {
      final drawing = _draw(
        const DiagramTable(
          balls: [],
          arrows: [
            TableArrow(
              id: 'a',
              kind: TableArrowKind.object,
              path: [Point(1, 2), Point(7, 2)],
              label: 'trajet',
            ),
          ],
        ),
      );
      final label = _tagged<PrintText>(drawing, 'label').single;
      final box = _box(label);

      // Le milieu du tracé est à 4 cases ; l'étiquette le recouvre ou le
      // jouxte, loin du départ (1 case) comme de l'arrivée (7 cases).
      const middle = _x + 4 * _cell;
      expect((box.left + box.right) / 2, closeTo(middle, 2 * _cell));
    });

    test('of an arrow with no length sit on its only point', () {
      final drawing = _draw(
        const DiagramTable(
          balls: [],
          arrows: [
            TableArrow(
              id: 'a',
              kind: TableArrowKind.indication,
              path: [Point(4, 2), Point(4, 2)],
              label: 'ici',
            ),
          ],
        ),
      );
      final label = _tagged<PrintText>(drawing, 'label').single;
      final point = _tagged<PrintPolyline>(
        drawing,
        'arrow',
      ).single.points.first;
      final box = _box(label);

      expect((box.left + box.right) / 2, closeTo(point.x, 1));
      expect(box.bottom, lessThanOrEqualTo(point.y));
    });

    test('are left out when the table has none', () {
      final drawing = _draw(
        DiagramTable(balls: [_ball('r', TableBallColor.red, 4, 2)]),
      );

      expect(_tagged(drawing, 'label'), isEmpty);
    });
  });
}

/// Boîte approchée d'un texte de la mesure à chasse fixe (0,5 em).
Rectangle<double> _box(PrintText t) {
  final width = t.text.runes.length * t.size * 0.5;
  final left = switch (t.align) {
    PrintAlign.left => t.x,
    PrintAlign.center => t.x - width / 2,
    PrintAlign.right => t.x - width,
  };
  return Rectangle<double>(left, t.y - t.size * 0.8, width, t.size);
}
