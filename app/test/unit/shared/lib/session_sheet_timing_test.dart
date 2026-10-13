import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/default_session_shapes.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:billard_cfa/shared/lib/session_sheet_timing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

void main() {
  group('distributeMinutes (largest remainder)', () {
    test('gives the pilot split for children theory: 8 / 5 / 7', () {
      // 20 x 3/8 = 7.5, 20 x 2/8 = 5, 20 x 3/8 = 7.5 : the first tie wins.
      expect(distributeMinutes(budget: 20, weights: [3, 2, 3]), [8, 5, 7]);
    });

    test('gives the pilot split for adults theory: 8 / 5 / 5 / 7', () {
      expect(distributeMinutes(budget: 25, weights: [3, 2, 2, 3]), [
        8,
        5,
        5,
        7,
      ]);
    });

    test('rounds to the largest fractional part: 23 / 12', () {
      // 35 x 2/3 = 23.33 and 35 x 1/3 = 11.67.
      expect(distributeMinutes(budget: 35, weights: [2, 1]), [23, 12]);
    });

    test('splits equal weights exactly: 25 / 25', () {
      expect(distributeMinutes(budget: 50, weights: [1, 1]), [25, 25]);
    });

    test('hands the leftover minutes to the highest elements on ties', () {
      // 10 / 3 = 3.33 each : one extra minute, given to the first.
      expect(distributeMinutes(budget: 10, weights: [1, 1, 1]), [4, 3, 3]);
      // 11 / 3 : two extra minutes, given to the first two.
      expect(distributeMinutes(budget: 11, weights: [1, 1, 1]), [4, 4, 3]);
    });

    test('ranks remainders before position', () {
      // 7 x 1/4 = 1.75, 7 x 3/4 = 5.25 : floors 1 + 5, the extra goes to the
      // larger remainder (the first), not the heavier weight.
      expect(distributeMinutes(budget: 7, weights: [1, 3]), [2, 5]);
    });

    test('always sums to the budget', () {
      for (var budget = 1; budget <= 40; budget++) {
        for (final weights in [
          [1],
          [1, 2],
          [3, 1, 4, 1, 5],
          [2, 2, 2, 2, 2, 2, 2],
        ]) {
          final minutes = distributeMinutes(budget: budget, weights: weights);
          expect(minutes.fold(0, (a, b) => a + b), budget);
        }
      }
    });

    test('gives nothing to elements without a weight', () {
      expect(distributeMinutes(budget: 20, weights: [null, 2, 0, 2]), [
        0,
        10,
        0,
        10,
      ]);
    });

    test('refuses a budget with nothing displayed', () {
      expect(
        () => distributeMinutes(budget: 10, weights: [null]),
        violation(InvariantCode.invalidSheet),
      );
      expect(
        () => distributeMinutes(budget: 10, weights: const []),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('allows an empty phase with no budget', () {
      expect(distributeMinutes(budget: 0, weights: const []), isEmpty);
    });
  });

  group('sessionSheetTiming', () {
    final children = {
      SessionPhase.welcome: <int?>[1],
      SessionPhase.notionAndInitiation: <int?>[3, 2, null, 3],
      SessionPhase.training: <int?>[2, 1],
      SessionPhase.game: <int?>[1],
      SessionPhase.review: <int?>[1],
    };

    test('reads the budgets from the injected shapes (children, 90 min)', () {
      final timing = sessionSheetTiming(
        audience: Audience.children,
        shapes: defaultSessionShapes,
        weights: children,
      );

      expect(timing[SessionPhase.welcome], [10]);
      expect(timing[SessionPhase.notionAndInitiation], [8, 5, 0, 7]);
      expect(timing[SessionPhase.training], [23, 12]);
      expect(timing[SessionPhase.game], [20]);
      expect(timing[SessionPhase.review], [5]);
    });

    test('uses the configured shape, not the default constant', () {
      const shapes = {
        Audience.children: SessionShape(
          phases: [
            PhaseSlot(phase: SessionPhase.welcome, minutes: 5),
            PhaseSlot(phase: SessionPhase.notionAndInitiation, minutes: 20),
            PhaseSlot(phase: SessionPhase.training, minutes: 40),
            PhaseSlot(phase: SessionPhase.game, minutes: 20),
            PhaseSlot(phase: SessionPhase.review, minutes: 5),
          ],
          exerciseCount: 2,
          recallCount: 0,
        ),
      };

      final timing = sessionSheetTiming(
        audience: Audience.children,
        shapes: shapes,
        weights: children,
      );

      expect(timing[SessionPhase.welcome], [5]);
      expect(timing[SessionPhase.training], [27, 13]);
    });

    test('sums to 120 for adults', () {
      final timing = sessionSheetTiming(
        audience: Audience.adults,
        shapes: defaultSessionShapes,
        weights: {
          SessionPhase.welcome: [1],
          SessionPhase.notionAndInitiation: [3, 2, 2, 3],
          SessionPhase.training: [1, 1],
          SessionPhase.game: [1],
          SessionPhase.review: [1],
        },
      );

      final total = timing.values.expand((m) => m).fold(0, (a, b) => a + b);
      expect(total, 120);
      expect(timing[SessionPhase.training], [25, 25]);
    });

    test('refuses a missing audience shape', () {
      expect(
        () => sessionSheetTiming(
          audience: Audience.adults,
          shapes: const {},
          weights: children,
        ),
        violation(InvariantCode.invalidRules),
      );
    });

    test('refuses a phase without weights entry', () {
      expect(
        () => sessionSheetTiming(
          audience: Audience.children,
          shapes: defaultSessionShapes,
          weights: {
            SessionPhase.welcome: [1],
          },
        ),
        violation(InvariantCode.invalidSheet),
      );
    });
  });
}
