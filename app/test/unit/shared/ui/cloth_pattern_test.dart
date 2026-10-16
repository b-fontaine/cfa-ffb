import 'package:billard_cfa/shared/ui/cloth_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('fills its parent without any semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(
      tester,
      const SizedBox(width: 200, height: 80, child: ClothPattern()),
    );

    expect(tester.getSize(find.byType(ClothPattern)), const Size(200, 80));
    expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
    handle.dispose();
  });

  testWidgets('paints the diamond grid in the cloth blue at low opacity', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const SizedBox(width: 200, height: 80, child: ClothPattern()),
    );

    final painter = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(ClothPattern),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter!;
    expect(painter, isA<ClothPatternPainter>());
    expect((painter as ClothPatternPainter).color.a, lessThan(0.1));
  });

  test('draws a grid of 8 columns by 4 rows', () {
    expect(ClothPatternPainter.columns, 8);
    expect(ClothPatternPainter.rows, 4);
  });
}
