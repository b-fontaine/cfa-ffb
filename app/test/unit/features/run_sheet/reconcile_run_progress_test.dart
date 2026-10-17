import 'package:billard_cfa/entities/run_progress/domain/run_progress.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/run_sheet/domain/reconcile_run_progress.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/run_plan_fixture.dart';

RunProgress _saved({
  int step = 2,
  Map<String, int> counts = const {},
  Map<String, Set<int>> checked = const {},
  int scoreA = 0,
  int timerSeconds = 0,
}) => RunProgress(
  key: RunProgressKey(sheetId: SheetId('demi-bille-1')),
  updatedAt: DateTime.utc(2026, 10, 16, 9),
  step: step,
  counts: counts,
  checked: checked,
  scoreA: scoreA,
  timerSeconds: timerSeconds,
);

void main() {
  final plan = runPlanFixture();

  test('leaves a progress that fits the session exactly as it is', () {
    final saved = _saved(
      step: 3,
      counts: {'ini': 2},
      checked: {
        'grille': {0, 1},
      },
      scoreA: 4,
      timerSeconds: 42,
    );

    expect(reconcileRunProgress(saved, plan), saved);
  });

  test('brings a step past the end back to the last step', () {
    expect(reconcileRunProgress(_saved(step: 9), plan).step, 4);
  });

  test('keeps the last step as it is', () {
    expect(reconcileRunProgress(_saved(step: 4), plan).step, 4);
  });

  test(
    'drops the counter of an initiation that is no longer in the session',
    () {
      final reconciled = reconcileRunProgress(
        _saved(counts: {'ini': 1, 'disparue': 3}),
        plan,
      );

      expect(reconciled.counts, {'ini': 1});
    },
  );

  test('drops the grid of an initiation that is no longer in the session', () {
    final reconciled = reconcileRunProgress(
      _saved(
        checked: {
          'grille': {0},
          'disparue': {1},
        },
      ),
      plan,
    );

    expect(reconciled.checked, {
      'grille': {0},
    });
  });

  test('brings a counter above the number of attempts back to it', () {
    expect(reconcileRunProgress(_saved(counts: {'ini': 7}), plan).counts, {
      'ini': 2,
    });
  });

  test('drops the criteria that are no longer in the grid', () {
    final reconciled = reconcileRunProgress(
      _saved(
        checked: {
          'grille': {0, 1, 2, 5},
        },
      ),
      plan,
    );

    expect(reconciled.checked, {
      'grille': {0, 1},
    });
  });

  test('drops a counter kept for an initiation that now has a grid', () {
    final reconciled = reconcileRunProgress(
      _saved(counts: {'grille': 1}),
      plan,
    );

    expect(reconciled.counts, isEmpty);
  });

  test('drops a grid kept for an initiation that now has a counter', () {
    final reconciled = reconcileRunProgress(
      _saved(
        checked: {
          'ini': {0},
        },
      ),
      plan,
    );

    expect(reconciled.checked, isEmpty);
  });

  test('keeps the score, the timer and the record as they were', () {
    final saved = _saved(scoreA: 3, timerSeconds: 17);

    final reconciled = reconcileRunProgress(saved, plan);

    expect(reconciled.scoreA, 3);
    expect(reconciled.timerSeconds, 17);
    expect(reconciled.updatedAt, saved.updatedAt);
  });

  test('is idempotent', () {
    final once = reconcileRunProgress(
      _saved(
        step: 12,
        counts: {'ini': 9, 'disparue': 1},
        checked: {
          'grille': {0, 7},
          'disparue': {1},
        },
      ),
      plan,
    );

    expect(reconcileRunProgress(once, plan), once);
  });

  test('keeps a counter exactly at the number of attempts, and zero', () {
    expect(reconcileRunProgress(_saved(counts: {'ini': 2}), plan).counts, {
      'ini': 2,
    });
    expect(reconcileRunProgress(_saved(counts: {'ini': 0}), plan).counts, {
      'ini': 0,
    });
  });

  test('keeps the last criterion of the grid and drops the one after it', () {
    final reconciled = reconcileRunProgress(
      _saved(
        checked: {
          'grille': {1, 2},
        },
      ),
      plan,
    );

    expect(reconciled.checked, {
      'grille': {1},
    });
  });

  group('isOrphanedProgress', () {
    final planned = Session(
      id: 'p1',
      title: 'Cours',
      date: DateTime(2026, 10, 12),
      audience: Audience.children,
      groupId: const GroupId('g1'),
    );
    RunProgressKey keyOf({String? session}) =>
        RunProgressKey(sheetId: SheetId('demi-bille-1'), sessionId: session);

    test('is false for a guide launched without a planned session', () {
      expect(isOrphanedProgress(keyOf(), plan), isFalse);
    });

    test('is false while the planned session still exists', () {
      expect(
        isOrphanedProgress(
          keyOf(session: 'p1'),
          plan.copyWith(planned: planned),
        ),
        isFalse,
      );
    });

    test('is true when the planned session is gone', () {
      expect(isOrphanedProgress(keyOf(session: 'p1'), plan), isTrue);
    });
  });
}
