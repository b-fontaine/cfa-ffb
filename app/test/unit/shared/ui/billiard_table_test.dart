import 'package:billard_cfa/shared/ui/ball_kind.dart';
import 'package:billard_cfa/shared/ui/billiard_table.dart';
import 'package:billard_cfa/shared/ui/table_geometry.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

RenderObject _paint(WidgetTester tester) => tester.renderObject(
  find
      .descendant(
        of: find.byType(BilliardTable),
        matching: find.byType(CustomPaint),
      )
      .first,
);

void main() {
  testWidgets('has the aspect ratio of a surface 2:1 plus half-case rails', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const Center(child: SizedBox(width: 450, child: BilliardTable())),
    );

    final size = tester.getSize(find.byType(BilliardTable));
    expect(size.width, 450);
    expect(size.height, closeTo(250, 0.01));
  });

  testWidgets('is described by a localised label', (tester) async {
    await pumpUi(tester, const BilliardTable());
    expect(
      find.bySemanticsLabel('Billiard table, seen from above'),
      findsOneWidget,
    );

    await pumpUi(tester, const BilliardTable(), locale: const Locale('fr'));
    expect(
      find.bySemanticsLabel('Table de billard, vue de dessus'),
      findsOneWidget,
    );
  });

  testWidgets('gives the overlay a geometry matching the painted table', (
    tester,
  ) async {
    TableGeometry? received;
    await pumpUi(
      tester,
      Center(
        child: SizedBox(
          width: 450,
          child: BilliardTable(
            overlay: (context, geometry) {
              received = geometry;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    final geometry = received!;
    expect(geometry.surface.width / geometry.surface.height, closeTo(2, 1e-9));
    expect(geometry.unit, closeTo(50, 0.01));
    final table = tester.getRect(find.byType(BilliardTable));
    expect(geometry.tableRect.size.width, closeTo(table.width, 0.01));
  });

  testWidgets('draws the overlay above the table', (tester) async {
    await pumpUi(
      tester,
      Center(
        child: SizedBox(
          width: 450,
          child: BilliardTable(
            overlay: (context, geometry) => const Text('on the table'),
          ),
        ),
      ),
    );

    expect(find.text('on the table'), findsOneWidget);
  });

  group('painted content', () {
    Future<List<Invocation>> record(
      WidgetTester tester,
      BilliardTable table, {
      ThemeData? theme,
    }) async {
      await pumpUi(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 450, child: table),
        ),
        theme: theme,
      );
      final painter = tester
          .widget<CustomPaint>(
            find
                .descendant(
                  of: find.byType(BilliardTable),
                  matching: find.byType(CustomPaint),
                )
                .first,
          )
          .painter!;
      final canvas = TestRecordingCanvas();
      painter.paint(canvas, tester.getSize(find.byType(BilliardTable)));
      return [for (final call in canvas.invocations) call.invocation];
    }

    TableGeometry geometryOf(WidgetTester tester) =>
        TableGeometry.fitting(tester.getSize(find.byType(BilliardTable)));

    Iterable<Invocation> calls(List<Invocation> all, Symbol name) =>
        all.where((c) => c.memberName == name);

    Paint paintOf(Invocation call) => call.positionalArguments.last as Paint;

    bool close(Offset a, Offset b) => (a - b).distance < 1e-6;

    testWidgets('paints the six pockets at their centres', (tester) async {
      final all = await record(tester, const BilliardTable());
      final geometry = geometryOf(tester);

      final circles = calls(all, #drawCircle).toList();
      expect(circles, hasLength(6));
      for (final pocket in TablePocket.values) {
        expect(
          circles.where(
            (c) =>
                close(
                  c.positionalArguments[0] as Offset,
                  geometry.pocketCenter(pocket),
                ) &&
                paintOf(c).color.toARGB32() ==
                    TableColors.light.pocket.toARGB32(),
          ),
          hasLength(1),
          reason: '$pocket',
        );
      }
    });

    testWidgets('paints each pocket at its real opening of 76.2 mm', (
      tester,
    ) async {
      final all = await record(tester, const BilliardTable());
      final geometry = geometryOf(tester);

      // 76,2 mm / 231,25 mm = 0,329514 case d'ouverture : rayon 0,164757 case,
      // soit 1,5 fois le diamètre d'une bille de but (50,8 mm).
      for (final circle in calls(all, #drawCircle)) {
        final radius = circle.positionalArguments[1] as double;
        expect(radius, closeTo(0.164757 * geometry.unit, 1e-3));
        expect(
          2 * radius / (2 * geometry.radiusPxOf(BallKind.red)),
          closeTo(1.5, 1e-3),
        );
      }
    });

    testWidgets('paints 18 diamonds on the rails, in the diamond colour', (
      tester,
    ) async {
      final all = await record(tester, const BilliardTable());
      final geometry = geometryOf(tester);

      final paths = calls(all, #drawPath).toList();
      expect(paths, hasLength(18));
      final centres = [
        for (final path in paths)
          (path.positionalArguments[0] as Path).getBounds().center,
      ];
      final expected = [
        for (final x in const [1.0, 2.0, 3.0, 5.0, 6.0, 7.0]) ...[
          Offset(x, -0.34),
          Offset(x, 4.34),
        ],
        for (final y in const [1.0, 2.0, 3.0]) ...[
          Offset(-0.34, y),
          Offset(8.34, y),
        ],
      ];
      for (final point in expected) {
        expect(
          centres.where((c) => close(c, geometry.toPixel(point))),
          hasLength(1),
          reason: 'diamond at $point',
        );
      }
      for (final path in paths) {
        expect(
          paintOf(path).color.toARGB32(),
          TableColors.light.diamond.toARGB32(),
        );
      }
    });

    testWidgets('the head string alone is one line at x = 2', (tester) async {
      final all = await record(
        tester,
        const BilliardTable(showHeadString: true),
      );
      final geometry = geometryOf(tester);

      final lines = calls(all, #drawLine).toList();
      expect(lines, hasLength(1));
      expect(
        close(
          lines.single.positionalArguments[0] as Offset,
          geometry.toPixel(const Offset(2, 0)),
        ),
        isTrue,
      );
      expect(
        close(
          lines.single.positionalArguments[1] as Offset,
          geometry.toPixel(const Offset(2, 4)),
        ),
        isTrue,
      );
      expect(
        paintOf(lines.single).color.toARGB32(),
        TableColors.light.headString.toARGB32(),
      );
    });

    testWidgets('the grid alone is made of 7 + 3 dashed lines', (tester) async {
      final all = await record(tester, const BilliardTable(showGrid: true));
      final geometry = geometryOf(tester);

      final lines = calls(all, #drawLine).toList();
      expect(lines, isNotEmpty);
      final verticals = <int>{};
      final horizontals = <int>{};
      for (final line in lines) {
        final a = line.positionalArguments[0] as Offset;
        final b = line.positionalArguments[1] as Offset;
        expect(
          paintOf(line).color.toARGB32(),
          TableColors.light.grid.withValues(alpha: 0.8).toARGB32(),
        );
        if ((a.dx - b.dx).abs() < 1e-6) {
          verticals.add(
            ((a.dx - geometry.surface.left) / geometry.unit).round(),
          );
        } else {
          expect(a.dy, closeTo(b.dy, 1e-6));
          horizontals.add(
            ((a.dy - geometry.surface.top) / geometry.unit).round(),
          );
        }
      }
      expect(verticals, {1, 2, 3, 4, 5, 6, 7});
      expect(horizontals, {1, 2, 3});
    });

    testWidgets('grid and head string together keep both', (tester) async {
      final all = await record(
        tester,
        const BilliardTable(showGrid: true, showHeadString: true),
      );
      final solid = calls(all, #drawLine).where(
        (c) =>
            paintOf(c).color.toARGB32() ==
            TableColors.light.headString.toARGB32(),
      );
      expect(solid, hasLength(1));
    });

    testWidgets('paints the cloth, cushion and rails of the dark theme', (
      tester,
    ) async {
      final all = await record(
        tester,
        const BilliardTable(),
        theme: AppTheme.dark(),
      );
      final rects = [
        for (final c in calls(all, #drawRRect)) paintOf(c).color.toARGB32(),
      ];
      expect(rects.first, TableColors.dark.rail.toARGB32());
      expect(rects[1], TableColors.dark.cushion.toARGB32());
      final cloth = calls(all, #drawRect).single;
      expect(paintOf(cloth).color.toARGB32(), BallColors.dark.cloth.toARGB32());
    });

    testWidgets('falls back to the light palette without a theme extension', (
      tester,
    ) async {
      final all = await record(
        tester,
        const BilliardTable(),
        theme: ThemeData(),
      );
      final first = calls(all, #drawRRect).first;
      expect(
        paintOf(first).color.toARGB32(),
        TableColors.light.rail.toARGB32(),
      );
      final cloth = calls(all, #drawRect).single;
      expect(
        paintOf(cloth).color.toARGB32(),
        BallColors.light.cloth.toARGB32(),
      );
    });
  });

  testWidgets('draws no line unless the grid or head string is requested', (
    tester,
  ) async {
    await pumpUi(tester, const SizedBox(width: 450, child: BilliardTable()));
    expect(_paint(tester), isNot(paints..line()));
  });

  testWidgets('survives a zero-sized area', (tester) async {
    await pumpUi(
      tester,
      const Center(child: SizedBox.shrink(child: BilliardTable())),
    );

    expect(tester.takeException(), isNull);
  });
}
