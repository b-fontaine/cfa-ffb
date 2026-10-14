import 'dart:ui' show PictureRecorder;

import 'package:billard_cfa/shared/ui/nav_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('is 24 dp by default and follows the current icon color', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const IconTheme(
        data: IconThemeData(color: Color(0xFF123456)),
        child: NavIcon(NavGlyph.today),
      ),
    );

    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(NavIcon),
        matching: find.byType(CustomPaint),
      ),
    );
    final painter = paint.painter! as NavIconPainter;

    expect(tester.getSize(find.byType(NavIcon)), const Size(24, 24));
    expect(painter.color, const Color(0xFF123456));
    expect(painter.filled, isFalse);
  });

  testWidgets('selected is filled and unselected is outlined', (tester) async {
    await pumpUi(
      tester,
      const Row(
        children: [
          NavIcon(NavGlyph.sessions),
          NavIcon(NavGlyph.sessions, selected: true),
        ],
      ),
    );

    final painters = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(NavIcon),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((paint) => paint.painter! as NavIconPainter)
        .toList();

    expect(painters.map((painter) => painter.filled), [false, true]);
    expect(painters.first.shouldRepaint(painters.last), isTrue);
  });

  testWidgets('is hidden from assistive technologies', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const NavIcon(NavGlyph.more));

    expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
    handle.dispose();
  });

  for (final glyph in NavGlyph.values) {
    for (final filled in [false, true]) {
      test('paints ${glyph.name} (filled: $filled) without error', () {
        final painter = NavIconPainter(
          glyph: glyph,
          filled: filled,
          color: Colors.black,
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        painter.paint(canvas, const Size(24, 24));

        expect(() => recorder.endRecording().dispose(), returnsNormally);
      });
    }
  }
}
