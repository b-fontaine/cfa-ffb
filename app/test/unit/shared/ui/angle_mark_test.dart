import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/ui/angle_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

Finder _painter() => find.byWidgetPredicate(
  (w) =>
      w is CustomPaint && w.painter.runtimeType.toString() == '_AnglePainter',
  description: '_AnglePainter',
);

void main() {
  final rays60 = <math.Point<double>>[
    math.Point<double>(4 + math.sqrt(3), 3),
    const math.Point(4, 2),
  ];

  testWidgets('computes the degrees from the rays and writes them', (
    tester,
  ) async {
    await pumpUi(
      tester,
      AngleMark(
        kind: AngleKind.naturalRejection,
        vertex: const math.Point(4, 4),
        rays: rays60,
      ),
    );

    expect(find.text('60°'), findsOneWidget);
  });

  testWidgets('is spoken with the kind and the degrees in French', (
    tester,
  ) async {
    await pumpUi(
      tester,
      AngleMark(
        kind: AngleKind.naturalRejection,
        vertex: const math.Point(4, 4),
        rays: rays60,
      ),
      locale: const Locale('fr'),
    );

    expect(find.bySemanticsLabel('Rejet naturel : 60°'), findsOneWidget);
  });

  testWidgets('names the three kinds in English', (tester) async {
    final expected = {
      AngleKind.bounce: 'Bounce angle: 60°',
      AngleKind.naturalRejection: 'Natural rejection: 60°',
      AngleKind.rightAngle: 'Right angle: 60°',
    };
    for (final entry in expected.entries) {
      await pumpUi(
        tester,
        AngleMark(
          kind: entry.key,
          vertex: const math.Point(4, 4),
          rays: rays60,
        ),
      );

      expect(find.bySemanticsLabel(entry.value), findsOneWidget);
    }
  });

  testWidgets('a right angle is marked by a square, an other by an arc', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const AngleMark(
        kind: AngleKind.rightAngle,
        vertex: math.Point(4, 2),
        rays: [math.Point(6, 2), math.Point(4, 0)],
      ),
    );
    final square = tester.renderObject(_painter());
    expect(find.text('90°'), findsOneWidget);
    expect(square, isNot(paints..arc()));

    await pumpUi(
      tester,
      AngleMark(
        kind: AngleKind.bounce,
        vertex: const math.Point(4, 4),
        rays: rays60,
      ),
    );
    expect(tester.renderObject(_painter()), paints..arc());
  });

  testWidgets('draws both rays from the vertex', (tester) async {
    await pumpUi(
      tester,
      const AngleMark(
        kind: AngleKind.rightAngle,
        vertex: math.Point(4, 2),
        rays: [math.Point(6, 2), math.Point(4, 0)],
      ),
    );

    expect(
      tester.renderObject(_painter()),
      paints
        ..line()
        ..line(),
    );
  });

  testWidgets('with fewer than two rays it draws no angle and no degrees', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const AngleMark(
        kind: AngleKind.bounce,
        vertex: math.Point(4, 4),
        rays: [math.Point(6, 2)],
      ),
    );

    expect(find.textContaining('°'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
