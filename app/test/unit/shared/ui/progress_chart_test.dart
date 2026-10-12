import 'package:billard_cfa/shared/ui/progress_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

ProgressChart _chart({
  List<ChartPoint> points = const [
    ChartPoint(value: 4, reached: false),
    ChartPoint(value: 7, reached: true),
  ],
  int maxValue = 9,
  int target = 7,
}) => ProgressChart(
  points: points,
  maxValue: maxValue,
  target: target,
  semanticLabel: 'Curve of 2 attempts',
  axisLabelX: 'Attempts',
  axisLabelY: 'Balls potted',
  targetLabel: 'Target: 7 balls',
);

ProgressChartPainter _painter({
  List<ChartPoint> points = const [],
  int maxValue = 10,
  int target = 5,
  Color line = Colors.blue,
}) => ProgressChartPainter(
  points: points,
  maxValue: maxValue,
  target: target,
  axisLabelX: 'x',
  axisLabelY: 'y',
  targetLabel: 't',
  lineColor: line,
  targetColor: Colors.red,
  axisColor: Colors.black,
  gridColor: Colors.grey,
  fillColor: Colors.white,
  labelStyle: const TextStyle(fontSize: 12),
  textDirection: TextDirection.ltr,
);

void main() {
  testWidgets('exposes one text summary instead of the drawing', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, _chart());

    expect(find.bySemanticsLabel('Curve of 2 attempts'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    handle.dispose();
  });

  testWidgets('paints without points', (tester) async {
    await pumpUi(tester, _chart(points: const []));

    expect(tester.takeException(), isNull);
  });

  testWidgets('paints a single point and many points', (tester) async {
    await pumpUi(
      tester,
      _chart(points: const [ChartPoint(value: 3, reached: false)]),
    );
    expect(tester.takeException(), isNull);

    await pumpUi(
      tester,
      _chart(
        points: [
          for (var i = 0; i < 30; i++)
            ChartPoint(value: i % 10, reached: i.isEven),
        ],
        maxValue: 16,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the given height', (tester) async {
    await pumpUi(tester, _chart());

    expect(tester.getSize(find.byType(ProgressChart)).height, 200);
  });

  test('places attempts evenly left to right and values bottom to top', () {
    final painter = _painter(
      points: const [
        ChartPoint(value: 0, reached: false),
        ChartPoint(value: 10, reached: true),
      ],
    );
    const area = Rect.fromLTRB(0, 0, 100, 100);

    final first = painter.position(area, 0, 0);
    final second = painter.position(area, 1, 10);

    expect(first, const Offset(25, 100));
    expect(second, const Offset(75, 0));
  });

  test('centres a single attempt', () {
    final painter = _painter(
      points: const [ChartPoint(value: 5, reached: true)],
    );

    final p = painter.position(const Rect.fromLTRB(0, 0, 100, 100), 0, 5);

    expect(p, const Offset(50, 50));
  });

  test('repaints only when something visible changes', () {
    final points = [ChartPoint(value: 1, reached: _flag())];
    final base = _painter(points: points);

    expect(base.shouldRepaint(_painter(points: points)), isFalse);
    expect(
      base.shouldRepaint(
        _painter(points: [ChartPoint(value: 1, reached: _flag())]),
      ),
      isTrue,
    );
    expect(base.shouldRepaint(_painter(points: points, maxValue: 12)), isTrue);
    expect(base.shouldRepaint(_painter(points: points, target: 6)), isTrue);
    expect(
      base.shouldRepaint(_painter(points: points, line: Colors.green)),
      isTrue,
    );
  });

  group('drawing', () {
    // Zone de tracé pour 300 x 240 : gauche 40, haut 16, droite 284, bas 200.
    const size = Size(300, 240);
    const left = 40.0;
    const right = 284.0;
    const top = 16.0;
    const bottom = 200.0;

    List<Invocation> record(ProgressChartPainter painter) {
      final canvas = _RecordingCanvas();
      painter.paint(canvas, size);
      return canvas.calls;
    }

    List<Invocation> lines(List<Invocation> calls, Color color) => [
      for (final call in calls)
        if (call.memberName == #drawLine &&
            (call.positionalArguments[2] as Paint).color == color)
          call,
    ];

    Offset from(Invocation call) => call.positionalArguments[0] as Offset;
    Offset to(Invocation call) => call.positionalArguments[1] as Offset;
    double width(Invocation call) =>
        (call.positionalArguments[2] as Paint).strokeWidth;

    List<Offset> texts(List<Invocation> calls) => [
      for (final call in calls)
        if (call.memberName == #drawParagraph)
          call.positionalArguments[1] as Offset,
    ];

    ProgressChartPainter chart({
      List<ChartPoint> points = const [],
      int maxValue = 10,
      int target = 5,
    }) => ProgressChartPainter(
      points: points,
      maxValue: maxValue,
      target: target,
      axisLabelX: 'x',
      axisLabelY: 'y',
      targetLabel: 't',
      lineColor: _blue,
      targetColor: _red,
      axisColor: _black,
      gridColor: _grey,
      fillColor: _white,
      labelStyle: const TextStyle(fontSize: 12),
      textDirection: TextDirection.ltr,
    );

    test('draws one grid line per tick across the plot area', () {
      final grid = lines(record(chart()), _grey);

      expect(grid, hasLength(6));
      for (var index = 0; index < 6; index++) {
        final y = bottom - (bottom - top) * (index * 2) / 10;
        expect(from(grid[index]), Offset(left, y));
        expect(to(grid[index]), Offset(right, y));
        expect(width(grid[index]), 1);
      }
    });

    test('picks the tick step from the maximum', () {
      int ticks(int maxValue) =>
          lines(record(chart(maxValue: maxValue)), _grey).length;

      expect(ticks(6), 7);
      expect(ticks(7), 4);
      expect(ticks(10), 6);
      expect(ticks(11), 3);
      expect(ticks(16), 5);
    });

    test('draws the two axes with a thicker stroke', () {
      final axes = lines(record(chart()), _black);

      expect(axes, hasLength(2));
      expect(from(axes[0]), const Offset(left, bottom));
      expect(to(axes[0]), const Offset(right, bottom));
      expect(from(axes[1]), const Offset(left, top));
      expect(to(axes[1]), const Offset(left, bottom));
      expect(width(axes[0]), 2);
      expect(width(axes[1]), 2);
    });

    test('draws the target as a dashed line at its height', () {
      final dashes = lines(record(chart()), _red);
      const y = bottom - (bottom - top) * 5 / 10;

      expect(dashes, hasLength(21));
      expect(from(dashes.first), const Offset(left, y));
      expect(to(dashes.first), const Offset(left + 6, y));
      expect(from(dashes[1]), const Offset(left + 12, y));
      expect(from(dashes.last), const Offset(left + 240, y));
      expect(to(dashes.last), const Offset(right, y));
      expect(width(dashes.first), 2);
    });

    test('joins the attempts with a stroked path', () {
      final calls = record(
        chart(
          points: const [
            ChartPoint(value: 0, reached: false),
            ChartPoint(value: 10, reached: true),
          ],
        ),
      );
      final paths = [
        for (final call in calls)
          if (call.memberName == #drawPath) call,
      ];

      expect(paths, hasLength(1));
      final bounds = (paths.single.positionalArguments[0] as Path).getBounds();
      expect(bounds.left, closeTo(left + 244 * 0.25, 0.001));
      expect(bounds.right, closeTo(left + 244 * 0.75, 0.001));
      expect(bounds.top, closeTo(top, 0.001));
      expect(bounds.bottom, closeTo(bottom, 0.001));
      final paint = paths.single.positionalArguments[1] as Paint;
      expect(paint.color, _blue);
      expect(paint.strokeWidth, 2.5);
      expect(paint.style, PaintingStyle.stroke);
    });

    test('draws no path for a single attempt', () {
      final calls = record(
        chart(points: const [ChartPoint(value: 3, reached: true)]),
      );

      expect(calls.where((call) => call.memberName == #drawPath), isEmpty);
    });

    test('shows a reached attempt as a disc and a missed one as a ring', () {
      final calls = record(
        chart(
          points: const [
            ChartPoint(value: 4, reached: true),
            ChartPoint(value: 4, reached: false),
          ],
        ),
      );
      final circles = [
        for (final call in calls)
          if (call.memberName == #drawCircle) call,
      ];
      const y = bottom - (bottom - top) * 4 / 10;
      const firstX = left + 244 * 0.25;
      const secondX = left + 244 * 0.75;
      Paint paint(int index) => circles[index].positionalArguments[2] as Paint;
      Offset center(int index) =>
          circles[index].positionalArguments[0] as Offset;
      double radius(int index) =>
          circles[index].positionalArguments[1] as double;

      expect(circles, hasLength(3));
      expect(center(0), const Offset(firstX, y));
      expect(radius(0), 6);
      expect(paint(0).color, _blue);
      expect(center(1), const Offset(secondX, y));
      expect(paint(1).color, _white);
      expect(center(2), const Offset(secondX, y));
      expect(radius(2), 6);
      expect(paint(2).color, _blue);
      expect(paint(2).style, PaintingStyle.stroke);
    });

    test('places every label next to its axis', () {
      final offsets = texts(
        record(
          chart(
            points: const [
              ChartPoint(value: 4, reached: true),
              ChartPoint(value: 6, reached: false),
            ],
            maxValue: 6,
            target: 3,
          ),
        ),
      );
      // Police de test : chaque caractère mesure 12 x 12.
      const targetY = bottom - (bottom - top) * 3 / 6;

      // Graduations : à gauche de l'axe, alignées à droite, centrées en y.
      expect(
        offsets,
        containsAll([
          const Offset(left - 6 - 12, bottom - 6),
          const Offset(left - 6 - 12, bottom - (bottom - top) * 3 / 6 - 6),
          const Offset(left - 6 - 12, top - 6),
        ]),
      );
      // Libellé de l'objectif : au bout de la ligne, au-dessus.
      expect(offsets, contains(const Offset(right - 12, targetY - 4 - 12)));
      // Numéros d'essai : centrés sous l'axe horizontal.
      expect(
        offsets,
        contains(const Offset(left + 244 * 0.25 - 6, bottom + 6)),
      );
      expect(
        offsets,
        contains(const Offset(left + 244 * 0.75 - 6, bottom + 6)),
      );
      // Titre de l'axe horizontal : centré, collé au bas.
      expect(
        offsets,
        contains(const Offset((left + right) / 2 - 6, 240 - 2 - 12)),
      );
      // Titre de l'axe vertical : en haut à gauche.
      expect(offsets, contains(Offset.zero));
    });

    test('repaints when any visible input changes', () {
      const points = [ChartPoint(value: 1, reached: true)];
      final base = chart(points: points);

      bool changed(ProgressChartPainter next) => base.shouldRepaint(next);

      expect(changed(chart(points: points, maxValue: 11)), isTrue);
      expect(changed(chart(points: points, target: 6)), isTrue);
      expect(
        changed(
          ProgressChartPainter(
            points: points,
            maxValue: 10,
            target: 5,
            axisLabelX: 'other',
            axisLabelY: 'y',
            targetLabel: 't',
            lineColor: _blue,
            targetColor: _red,
            axisColor: _black,
            gridColor: _grey,
            fillColor: _white,
            labelStyle: const TextStyle(fontSize: 12),
            textDirection: TextDirection.ltr,
          ),
        ),
        isTrue,
      );
      expect(
        changed(
          ProgressChartPainter(
            points: points,
            maxValue: 10,
            target: 5,
            axisLabelX: 'x',
            axisLabelY: 'other',
            targetLabel: 't',
            lineColor: _blue,
            targetColor: _red,
            axisColor: _black,
            gridColor: _grey,
            fillColor: _white,
            labelStyle: const TextStyle(fontSize: 12),
            textDirection: TextDirection.ltr,
          ),
        ),
        isTrue,
      );
      expect(
        changed(
          ProgressChartPainter(
            points: points,
            maxValue: 10,
            target: 5,
            axisLabelX: 'x',
            axisLabelY: 'y',
            targetLabel: 'other',
            lineColor: _blue,
            targetColor: _red,
            axisColor: _black,
            gridColor: _grey,
            fillColor: _white,
            labelStyle: const TextStyle(fontSize: 12),
            textDirection: TextDirection.ltr,
          ),
        ),
        isTrue,
      );
      expect(
        changed(
          ProgressChartPainter(
            points: points,
            maxValue: 10,
            target: 5,
            axisLabelX: 'x',
            axisLabelY: 'y',
            targetLabel: 't',
            lineColor: _blue,
            targetColor: _green,
            axisColor: _black,
            gridColor: _grey,
            fillColor: _white,
            labelStyle: const TextStyle(fontSize: 12),
            textDirection: TextDirection.ltr,
          ),
        ),
        isTrue,
      );
    });
  });
}

/// Canvas qui enregistre les appels de dessin (aucun rendu).
const _blue = Color(0xFF0000FF);
const _red = Color(0xFFFF0000);
const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);
const _grey = Color(0xFFFF00FF);
const _green = Color(0xFF00FF00);

class _RecordingCanvas implements Canvas {
  final List<Invocation> calls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    return null;
  }
}

bool _flag() => DateTime.now().year > 2000;
