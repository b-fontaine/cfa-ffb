import 'package:billard_cfa/shared/ui/stance_diagram.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  group('layout', () {
    test('the shooter faces the ball: right side is below the cue axis', () {
      expect(StanceLayout.rightFoot.dy, greaterThan(0.5));
      expect(StanceLayout.leftFoot.dy, lessThan(0.5));
      expect(StanceLayout.eye(StanceLeadEye.right).dy, greaterThan(0.5));
      expect(StanceLayout.eye(StanceLeadEye.left).dy, lessThan(0.5));
    });

    test('the cue axis runs from the butt to the ball through the head', () {
      expect(StanceLayout.butt.dy, 0.5);
      expect(StanceLayout.ball.dy, 0.5);
      expect(StanceLayout.head.dy, 0.5);
      expect(StanceLayout.butt.dx, lessThan(StanceLayout.head.dx));
      expect(StanceLayout.head.dx, lessThan(StanceLayout.bridge.dx));
      expect(StanceLayout.bridge.dx, lessThan(StanceLayout.ball.dx));
    });

    test('both eyes are on the head, at the same distance from the axis', () {
      final right = StanceLayout.eye(StanceLeadEye.right);
      final left = StanceLayout.eye(StanceLeadEye.left);

      expect(right.dx, left.dx);
      expect(right.dy - 0.5, closeTo(0.5 - left.dy, 1e-12));
    });
  });

  testWidgets('is spoken with the parts of the stance in French', (
    tester,
  ) async {
    await pumpUi(tester, const StanceDiagram(), locale: const Locale('fr'));

    expect(
      find.bySemanticsLabel(
        'Posture vue de dessus : pieds, hanches, queue, main de chevalet et '
        'œil directeur.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('writes the five labelled parts', (tester) async {
    await pumpUi(tester, const StanceDiagram(), locale: const Locale('fr'));

    for (final label in [
      'Pieds',
      'Hanches',
      'Queue',
      'Main de chevalet',
      'Œil directeur',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('writes the annotations and speaks them after the parts', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const StanceDiagram(
        annotations: ['Pied droit sous la main droite', 'Avant-bras vertical'],
      ),
      locale: const Locale('fr'),
    );

    expect(find.text('Pied droit sous la main droite'), findsOneWidget);
    expect(find.text('Avant-bras vertical'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Posture vue de dessus : pieds, hanches, queue, main de chevalet et '
        'œil directeur. Pied droit sous la main droite ; Avant-bras vertical',
      ),
      findsOneWidget,
    );
  });

  testWidgets('writes the English parts', (tester) async {
    await pumpUi(tester, const StanceDiagram());

    expect(find.text('Feet'), findsOneWidget);
    expect(find.text('Lead eye'), findsOneWidget);
  });

  testWidgets('does not overflow on a narrow width', (tester) async {
    await pumpUi(
      tester,
      const Center(
        child: SizedBox(
          width: 180,
          child: StanceDiagram(annotations: ['a', 'b']),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
