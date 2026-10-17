import 'dart:math' show Point;

import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/presentation/ui/print_scene_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _black = Color(0xFF000000);
const _dark = Color(0xFF545454);
const _light = Color(0xFFADADAD);
const _white = Color(0xFFFFFFFF);

PrintPage _page(List<PrintItem> items) =>
    PrintPage(width: 200, height: 100, items: items);

Future<RenderObject> _pump(WidgetTester tester, PrintPage page) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 200,
          height: 100,
          child: CustomPaint(
            key: const ValueKey('page'),
            painter: PrintScenePainter(page),
          ),
        ),
      ),
    ),
  );
  return tester.renderObject(find.byKey(const ValueKey('page')));
}

void main() {
  testWidgets('paints a white sheet first', (tester) async {
    final render = await _pump(tester, _page(const []));

    expect(render, paints..rect(color: _white));
  });

  testWidgets('paints a text as a paragraph', (tester) async {
    final render = await _pump(
      tester,
      _page(const [PrintText(x: 10, y: 20, text: 'Bonjour', size: 12)]),
    );

    expect(render, paints..paragraph());
  });

  testWidgets('paints a vertical text turned a quarter to the right', (
    tester,
  ) async {
    final render = await _pump(
      tester,
      _page(const [
        PrintText(x: 10, y: 20, text: 'Haut', size: 12, rotated: true),
      ]),
    );

    expect(
      render,
      paints
        ..rotate(angle: 3.141592653589793 / 2)
        ..paragraph(),
    );
  });

  testWidgets('paints a line with its shade', (tester) async {
    final render = await _pump(
      tester,
      _page(const [
        PrintLine(
          from: Point(0, 0),
          to: Point(100, 50),
          shade: PrintShade.darkGray,
        ),
      ]),
    );

    expect(render, paints..path(color: _dark, style: PaintingStyle.stroke));
  });

  testWidgets('paints a dashed line as shorter segments than a plain one', (
    tester,
  ) async {
    final plain = await _pump(
      tester,
      _page(const [PrintLine(from: Point(0, 0), to: Point(100, 0))]),
    );
    final plainLength = _pathLength(plain);
    final dashed = await _pump(
      tester,
      _page(const [
        PrintLine(from: Point(0, 0), to: Point(100, 0), dash: [4, 4]),
      ]),
    );

    expect(plainLength, closeTo(100, 1e-6));
    expect(_pathLength(dashed), closeTo(52, 1e-3));
  });

  testWidgets('paints a polyline of several points', (tester) async {
    final render = await _pump(
      tester,
      _page(const [
        PrintPolyline(points: [Point(0, 0), Point(50, 50), Point(100, 0)]),
      ]),
    );

    expect(render, paints..path(color: _black, style: PaintingStyle.stroke));
  });

  testWidgets('skips a polyline of a single point', (tester) async {
    final render = await _pump(
      tester,
      _page(const [
        PrintPolyline(points: [Point(0, 0)]),
      ]),
    );

    expect(_pathCalls(render), 0);
  });

  testWidgets('paints a rectangle filled then outlined', (tester) async {
    final render = await _pump(
      tester,
      _page(const [
        PrintRect(
          x: 5,
          y: 5,
          width: 50,
          height: 20,
          fill: PrintShade.lightGray,
          stroke: PrintShade.black,
        ),
      ]),
    );

    expect(
      render,
      paints
        ..path(color: _light, style: PaintingStyle.fill)
        ..path(color: _black, style: PaintingStyle.stroke),
    );
  });

  testWidgets('paints a circle as a filled shape', (tester) async {
    final render = await _pump(
      tester,
      _page(const [
        PrintCircle(center: Point(50, 50), radius: 10, fill: PrintShade.black),
      ]),
    );

    expect(render, paints..path(color: _black, style: PaintingStyle.fill));
  });

  testWidgets('paints a polygon filled', (tester) async {
    final render = await _pump(
      tester,
      _page(const [
        PrintPolygon(
          points: [Point(10, 10), Point(30, 10), Point(20, 30)],
          fill: PrintShade.darkGray,
        ),
      ]),
    );

    expect(render, paints..path(color: _dark, style: PaintingStyle.fill));
  });

  testWidgets('scales the page to the width available', (tester) async {
    final render = await _pump(
      tester,
      const PrintPage(
        width: 100,
        height: 50,
        items: [
          PrintRect(
            x: 10,
            y: 10,
            width: 20,
            height: 10,
            fill: PrintShade.black,
          ),
        ],
      ),
    );

    // La page de 100 points est montrée sur 200 pixels : échelle 2.
    expect(render, paints..path(color: _black, style: PaintingStyle.fill));
    final box = render as RenderBox;
    expect(box.size.width, 200);
  });

  testWidgets('repaints only when the page or the font changes', (
    tester,
  ) async {
    final page = _page(const []);
    final same = PrintScenePainter(page);

    expect(same.shouldRepaint(PrintScenePainter(page)), isFalse);
    expect(same.shouldRepaint(PrintScenePainter(_page(const []))), isTrue);
    expect(
      same.shouldRepaint(PrintScenePainter(page, fontFamily: 'Exo2')),
      isTrue,
    );
  });

  test('maps the four shades to four distinct greys', () {
    final colors = {
      for (final s in PrintShade.values) PrintScenePainter.color(s),
    };

    expect(colors, {_black, _dark, _light, _white});
  });
}

int _pathCalls(RenderObject render) {
  var count = 0;
  expect(
    render,
    paints..everything((method, arguments) {
      if (method == #drawPath) count++;
      return true;
    }),
  );
  return count;
}

double _pathLength(RenderObject render) {
  var length = 0.0;
  expect(
    render,
    paints..everything((method, arguments) {
      if (method == #drawPath) {
        for (final metric in (arguments[0] as Path).computeMetrics()) {
          length += metric.length;
        }
      }
      return true;
    }),
  );
  return length;
}
