import 'package:billard_cfa/entities/session_sheet/domain/audience_weight.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_timing.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/default_session_shapes.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/session_sheet_fixtures.dart';

void main() {
  // Séance pilote (FORMAT § 9) : poids de théorie 3/2/(2 adultes), initiation
  // 3, exercices 2/1 (enfants) et 1/1 (adultes).
  final pilot = buildSheet(
    theory: [
      theorySection('tangente', weight: AudienceWeight(children: 3, adults: 3)),
      theorySection('comparer', weight: AudienceWeight(children: 2, adults: 2)),
      theorySection('fantome', weight: AudienceWeight(adults: 2)),
    ],
    initiation: [sheetInitiation('ini-7')],
    exercises: [
      sheetExercise('e1', 1, weight: AudienceWeight(children: 2, adults: 1)),
      sheetExercise('e2', 2, weight: AudienceWeight(children: 1, adults: 1)),
    ],
  );
  // Les poids de l'initiation du fixture valent 1/1 : on les règle comme le
  // pilote (3/3) pour retrouver les valeurs normatives du FORMAT § 9.
  final heavy = pilot.copyWith(
    initiation: [
      for (final item in pilot.initiation)
        item.copyWith(weight: AudienceWeight(children: 3, adults: 3)),
    ],
  );

  // Depuis l'ADR 0011, le créneau de rappel (poids 1) partage le budget
  // d'entraînement avec les exercices : 35 min en 2/1/1 et 50 min en 1/1/1.
  test('gives the normative children timing of the pilot: 8 / 5 / 7', () {
    final timing = sheetTiming(
      heavy,
      audience: Audience.children,
      shapes: defaultSessionShapes,
    );

    expect(timing.recall, 10);
    expect(timing.theory, {'tangente': 8, 'comparer': 5});
    expect(timing.initiation, {'ini-7': 7});
    expect(timing.exercises, {'e1': 17, 'e2': 9});
    expect(timing.recallExercise, 9);
    expect(timing.game, 20);
    expect(timing.review, 5);
    expect(timing.total, 90);
  });

  test('gives the normative adults timing of the pilot: 8 / 5 / 5 / 7', () {
    final timing = sheetTiming(
      heavy,
      audience: Audience.adults,
      shapes: defaultSessionShapes,
    );

    expect(timing.theory, {'tangente': 8, 'comparer': 5, 'fantome': 5});
    expect(timing.initiation, {'ini-7': 7});
    expect(timing.exercises, {'e1': 17, 'e2': 17});
    expect(timing.recallExercise, 16);
    expect(timing.game, 25);
    expect(timing.review, 10);
    expect(timing.total, 120);
  });

  test('exposes the minutes of each phase', () {
    final timing = sheetTiming(
      heavy,
      audience: Audience.children,
      shapes: defaultSessionShapes,
    );

    expect(timing.phaseMinutes, {
      SessionPhase.welcome: 10,
      SessionPhase.notionAndInitiation: 20,
      SessionPhase.training: 35,
      SessionPhase.game: 20,
      SessionPhase.review: 5,
    });
  });

  test('does not list the elements hidden for the audience', () {
    final timing = sheetTiming(
      heavy,
      audience: Audience.children,
      shapes: defaultSessionShapes,
    );

    expect(timing.theory.containsKey('fantome'), isFalse);
  });

  test(
    'reads the phase budgets from the injected shapes, hidden elements out',
    () {
      const children = SessionShape(
        phases: [
          PhaseSlot(phase: SessionPhase.welcome, minutes: 10),
          PhaseSlot(phase: SessionPhase.notionAndInitiation, minutes: 15),
          PhaseSlot(phase: SessionPhase.training, minutes: 40),
          PhaseSlot(phase: SessionPhase.game, minutes: 20),
          PhaseSlot(phase: SessionPhase.review, minutes: 5),
        ],
        exerciseCount: 2,
        recallCount: 0,
      );
      final sheet = buildSheet(
        theory: [
          theorySection('a', weight: AudienceWeight(children: 1, adults: 1)),
          theorySection('b', weight: AudienceWeight(children: 2)),
        ],
        exercises: [
          sheetExercise(
            'e1',
            1,
            weight: AudienceWeight(children: 3, adults: 1),
          ),
          sheetExercise(
            'e2',
            2,
            weight: AudienceWeight(children: 1, adults: 1),
          ),
          sheetExercise('e3', 3, weight: AudienceWeight(children: 1)),
        ],
      );
      final shapes = {
        Audience.children: children,
        Audience.adults: defaultSessionShapes[Audience.adults]!,
      };

      final kids = sheetTiming(
        sheet,
        audience: Audience.children,
        shapes: shapes,
      );
      final grownUps = sheetTiming(
        sheet,
        audience: Audience.adults,
        shapes: shapes,
      );

      expect(kids.theory, {'a': 5, 'b': 10});
      expect(kids.exercises, {'e1': 20, 'e2': 7, 'e3': 7});
      expect(kids.recallExercise, 6);
      expect(kids.total, 90);
      expect(grownUps.theory, {'a': 25});
      expect(grownUps.exercises, {'e1': 17, 'e2': 17});
      expect(grownUps.recallExercise, 16);
      expect(grownUps.total, 120);
    },
  );
}
