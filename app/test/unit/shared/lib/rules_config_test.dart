import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/default_session_shapes.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

void main() {
  group('defaults (ADR 0003)', () {
    final config = RulesConfig();

    test('an exercise is validated after 5 passed passes', () {
      expect(config.passesRequired, 5);
    });

    test('thresholds are the configured proposals', () {
      expect(config.alertThreshold, 3);
      expect(config.persistentAlertThreshold, 5);
      expect(config.recallStaleSessions, 4);
      expect(config.groupFailureSharePercent, 50);
      expect(config.trendWindow, 5);
      expect(config.movingAverageWindow, 3);
      expect(config.stagnationPasses, 5);
      expect(config.maxPassesPerExercisePerSession, 2);
      expect(config.minDistinctExercises, 2);
      expect(config.readinessMinScore, 3);
      expect(config.backupReminderDays, 30);
    });

    test('children phases are 10/20/35/20/5 (90 min)', () {
      final phases = config.shapes[Audience.children]!.phases;

      expect(phases.map((slot) => slot.minutes), [10, 20, 35, 20, 5]);
      expect(phases.map((slot) => slot.phase), SessionPhase.values);
    });

    test('adults phases are 10/25/50/25/10 (120 min)', () {
      final phases = config.shapes[Audience.adults]!.phases;

      expect(phases.map((slot) => slot.minutes), [10, 25, 50, 25, 10]);
    });

    test('adults get one recall exercise, children none', () {
      expect(config.shapes[Audience.adults]!.recallCount, 1);
      expect(config.shapes[Audience.children]!.recallCount, 0);
    });

    test('standard equals the default configuration', () {
      expect(RulesConfig.standard(), config);
    });
  });

  group('validation', () {
    test('accepts the backup reminder delay from 1 to 365 days', () {
      expect(RulesConfig(backupReminderDays: 1).backupReminderDays, 1);
      expect(RulesConfig(backupReminderDays: 365).backupReminderDays, 365);
    });

    test('refuses a backup reminder delay of 0 or 366 days', () {
      expect(
        () => RulesConfig(backupReminderDays: 0),
        violation(InvariantCode.invalidRules),
      );
      expect(
        () => RulesConfig(backupReminderDays: 366),
        violation(InvariantCode.invalidRules),
      );
    });

    test('accepts passesRequired 1', () {
      expect(RulesConfig(passesRequired: 1).passesRequired, 1);
    });

    test('refuses passesRequired 0', () {
      expect(
        () => RulesConfig(passesRequired: 0),
        violation(InvariantCode.invalidRules),
      );
    });

    test('refuses alertThreshold 0', () {
      expect(
        () => RulesConfig(alertThreshold: 0),
        violation(InvariantCode.invalidRules),
      );
    });

    test('accepts a persistent threshold equal to the alert threshold', () {
      expect(
        RulesConfig(
          alertThreshold: 4,
          persistentAlertThreshold: 4,
        ).alertThreshold,
        4,
      );
    });

    test('refuses a persistent threshold below the alert threshold', () {
      expect(
        () => RulesConfig(alertThreshold: 4, persistentAlertThreshold: 3),
        violation(InvariantCode.invalidRules),
      );
    });

    test('refuses recallStaleSessions 0', () {
      expect(
        () => RulesConfig(recallStaleSessions: 0),
        violation(InvariantCode.invalidRules),
      );
    });

    test('refuses a trend window of 1 (no slope with one point)', () {
      expect(
        () => RulesConfig(trendWindow: 1),
        violation(InvariantCode.invalidRules),
      );
    });

    test('accepts a trend window of 2', () {
      expect(RulesConfig(trendWindow: 2).trendWindow, 2);
    });

    test('refuses movingAverageWindow 0', () {
      expect(
        () => RulesConfig(movingAverageWindow: 0),
        violation(InvariantCode.invalidRules),
      );
    });

    test('refuses stagnationPasses 0', () {
      expect(
        () => RulesConfig(stagnationPasses: 0),
        violation(InvariantCode.invalidRules),
      );
    });

    test('refuses maxPassesPerExercisePerSession 0', () {
      expect(
        () => RulesConfig(maxPassesPerExercisePerSession: 0),
        violation(InvariantCode.invalidRules),
      );
    });

    test('refuses minDistinctExercises 0', () {
      expect(
        () => RulesConfig(minDistinctExercises: 0),
        violation(InvariantCode.invalidRules),
      );
    });

    test('accepts a group failure share of 1 and 100 percent', () {
      expect(RulesConfig(groupFailureSharePercent: 1).trendWindow, 5);
      expect(RulesConfig(groupFailureSharePercent: 100).trendWindow, 5);
    });

    test('refuses a group failure share of 0 and 101 percent', () {
      expect(
        () => RulesConfig(groupFailureSharePercent: 0),
        violation(InvariantCode.invalidRules),
      );
      expect(
        () => RulesConfig(groupFailureSharePercent: 101),
        violation(InvariantCode.invalidRules),
      );
    });

    test('accepts readiness scores 1 and 4, refuses 0 and 5', () {
      expect(RulesConfig(readinessMinScore: 1).readinessMinScore, 1);
      expect(RulesConfig(readinessMinScore: 4).readinessMinScore, 4);
      expect(
        () => RulesConfig(readinessMinScore: 0),
        violation(InvariantCode.invalidRules),
      );
      expect(
        () => RulesConfig(readinessMinScore: 5),
        violation(InvariantCode.invalidRules),
      );
    });
  });

  group('session shapes', () {
    SessionShape shape({
      List<int> minutes = const [10, 20, 35, 20, 5],
      int exercises = 2,
      int recall = 0,
      List<SessionPhase>? order,
    }) => SessionShape(
      phases: [
        for (var i = 0; i < minutes.length; i++)
          PhaseSlot(
            phase: (order ?? SessionPhase.values)[i],
            minutes: minutes[i],
          ),
      ],
      exerciseCount: exercises,
      recallCount: recall,
    );

    Map<Audience, SessionShape> shapes(SessionShape children) => {
      Audience.children: children,
      Audience.adults: defaultSessionShapes[Audience.adults]!,
    };

    test('accepts a custom timing summing to the audience duration', () {
      final config = RulesConfig(
        shapes: shapes(shape(minutes: [15, 15, 35, 20, 5])),
      );

      expect(config.shapes[Audience.children]!.phases.first.minutes, 15);
    });

    test('refuses a sum of 89 minutes', () {
      expect(
        () => RulesConfig(shapes: shapes(shape(minutes: [10, 20, 35, 20, 4]))),
        violation(InvariantCode.invalidRules),
      );
    });

    test('refuses a sum of 91 minutes', () {
      expect(
        () => RulesConfig(shapes: shapes(shape(minutes: [10, 20, 35, 20, 6]))),
        violation(InvariantCode.invalidRules),
      );
    });

    test('accepts a phase of exactly 1 minute', () {
      final config = RulesConfig(
        shapes: shapes(shape(minutes: [1, 29, 35, 20, 5])),
      );

      expect(config.shapes[Audience.children]!.phases.first.minutes, 1);
    });

    test('refuses a phase of 0 minutes', () {
      expect(
        () => RulesConfig(shapes: shapes(shape(minutes: [0, 30, 35, 20, 5]))),
        violation(InvariantCode.invalidRules),
      );
    });

    test(
      'refuses phases that are not welcome, notion, training, game, review',
      () {
        expect(
          () => RulesConfig(
            shapes: shapes(
              shape(
                order: [
                  SessionPhase.notionAndInitiation,
                  SessionPhase.welcome,
                  SessionPhase.training,
                  SessionPhase.game,
                  SessionPhase.review,
                ],
              ),
            ),
          ),
          violation(InvariantCode.invalidRules),
        );
      },
    );

    test('refuses fewer than five phases', () {
      expect(
        () => RulesConfig(shapes: shapes(shape(minutes: [10, 20, 60]))),
        violation(InvariantCode.invalidRules),
      );
    });

    test('refuses a missing audience', () {
      expect(
        () => RulesConfig(
          shapes: {Audience.adults: defaultSessionShapes[Audience.adults]!},
        ),
        violation(InvariantCode.invalidRules),
      );
    });

    test('refuses 0 exercises', () {
      expect(
        () => RulesConfig(shapes: shapes(shape(exercises: 0, recall: 1))),
        violation(InvariantCode.invalidRules),
      );
    });

    test('refuses a recall count above 1', () {
      expect(
        () => RulesConfig(shapes: shapes(shape(recall: 2))),
        violation(InvariantCode.invalidRules),
      );
    });

    test('refuses a negative recall count', () {
      expect(
        () => RulesConfig(shapes: shapes(shape(recall: -1))),
        violation(InvariantCode.invalidRules),
      );
    });

    test('refuses fewer exercises than the minimum of distinct exercises', () {
      expect(
        () => RulesConfig(shapes: shapes(shape(exercises: 1))),
        violation(InvariantCode.invalidRules),
      );
    });

    test('counts the recall exercise toward the minimum', () {
      final config = RulesConfig(
        shapes: shapes(shape(exercises: 1, recall: 1)),
      );

      expect(config.shapes[Audience.children]!.exerciseCount, 1);
    });
  });
}
