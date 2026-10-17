import 'dart:async';

import 'package:billard_cfa/entities/session_sheet/domain/scoring.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_timing.dart';
import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_mode.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_step.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_ticker.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/lib/timer_tone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/run_progress_support.dart';
import '../../../../support/session_sheet_fixtures.dart';

class _MockResolve extends Mock implements ResolveRunPlan;

/// Minuteur factice : les secondes s'écoulent quand le test le décide.
class _FakeTicker implements RunTicker {
  final controller = StreamController<void>.broadcast(sync: true);

  @override
  Stream<void> ticks() => controller.stream;

  bool get hasListener => controller.hasListener;

  void tick([int seconds = 1]) {
    for (var i = 0; i < seconds; i++) {
      controller.add(null);
    }
  }
}

RunPlan _plan() {
  final sheet = buildSheet(
    initiation: [
      sheetInitiation('ini', scoring: const Scoring.counter(of: 2)),
      sheetInitiation(
        'grille',
        scoring: const Scoring.checklist(criteria: ['a', 'b']),
      ),
    ],
  );
  return RunPlan(
    sheet: sheet,
    audience: Audience.children,
    partCount: 2,
    timing: sheetTiming(
      sheet,
      audience: Audience.children,
      shapes: RulesConfig().shapes,
    ),
    steps: const [
      RunStep(
        kind: RunStepKind.recall,
        phase: SessionPhase.welcome,
        minutes: 10,
      ),
      RunStep(
        kind: RunStepKind.theory,
        phase: SessionPhase.notionAndInitiation,
        minutes: 20,
        elementId: 't1',
      ),
      RunStep(
        kind: RunStepKind.initiation,
        phase: SessionPhase.notionAndInitiation,
        minutes: 5,
        elementId: 'ini',
      ),
      RunStep(
        kind: RunStepKind.exercise,
        phase: SessionPhase.training,
        minutes: 35,
        elementId: 'e1',
      ),
      RunStep(kind: RunStepKind.game, phase: SessionPhase.game, minutes: 20),
    ],
    passesRequired: 5,
  );
}

void main() {
  late _MockResolve resolve;
  late _FakeTicker ticker;
  final key = RunKey(sheetId: SheetId('demi-bille-1'));

  setUpAll(() => registerFallbackValue(SheetId('x-1')));
  setUp(() {
    resolve = _MockResolve();
    ticker = _FakeTicker();
    when(
      () => resolve(
        any(),
        audience: any(named: 'audience'),
        sessionId: any(named: 'sessionId'),
      ),
    ).thenAnswer((_) async => Ok(_plan()));
  });

  RunSheetCubit build() =>
      RunSheetCubit(resolve, ticker, key, inMemoryRunProgressKeeper());

  Future<RunSheetCubit> ready() async {
    final cubit = build();
    await cubit.load();
    return cubit;
  }

  group('load', () {
    test('resolves the plan of its key', () async {
      final cubit = build();
      final withAudience = RunSheetCubit(
        resolve,
        ticker,
        RunKey(
          sheetId: SheetId('demi-bille-1'),
          audience: Audience.adults,
          sessionId: 'p1',
        ),
        inMemoryRunProgressKeeper(),
      );

      await cubit.load();
      await withAudience.load();

      verify(() => resolve(SheetId('demi-bille-1'))).called(1);
      verify(
        () => resolve(
          SheetId('demi-bille-1'),
          audience: Audience.adults,
          sessionId: 'p1',
        ),
      ).called(1);
      expect(cubit.state.status, RunStatus.ready);
      expect(cubit.state.step, 0);
      expect(cubit.state.currentStep?.kind, RunStepKind.recall);
    });

    test('loads only once', () async {
      final cubit = await ready();

      await cubit.load();

      verify(
        () => resolve(
          any(),
          audience: any(named: 'audience'),
          sessionId: any(named: 'sessionId'),
        ),
      ).called(1);
    });

    test('keeps the step asked for before the plan arrived', () async {
      final cubit = build()..showStep(3);

      await cubit.load();

      expect(cubit.state.step, 3);
    });

    test('clamps a step asked for beyond the plan', () async {
      final cubit = build()..showStep(99);

      await cubit.load();

      expect(cubit.state.step, 4);
    });

    test('reports an unknown session', () async {
      when(
        () => resolve(
          any(),
          audience: any(named: 'audience'),
          sessionId: any(named: 'sessionId'),
        ),
      ).thenAnswer((_) async => const Err(NotFound('sheet', 'x')));
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, RunStatus.notFound);
      expect(cubit.state.currentStep, isNull);
    });

    test('reports a failure and retries on the next load', () async {
      var calls = 0;
      when(
        () => resolve(
          any(),
          audience: any(named: 'audience'),
          sessionId: any(named: 'sessionId'),
        ),
      ).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? const Err(InvariantViolation(InvariantCode.invalidSheet))
            : Ok(_plan());
      });
      final cubit = build();

      await cubit.load();
      expect(cubit.state.status, RunStatus.failure);
      expect(cubit.state.failure, isA<InvariantViolation>());
      await cubit.load();

      expect(cubit.state.status, RunStatus.ready);
      expect(cubit.state.failure, isNull);
    });
  });

  group('steps', () {
    test('moves freely between the steps', () async {
      final cubit = await ready();

      cubit.showStep(4);
      expect(cubit.state.currentStep?.kind, RunStepKind.game);
      cubit.showStep(1);
      expect(cubit.state.currentStep?.kind, RunStepKind.theory);
    });

    test('clamps the step into the range', () async {
      final cubit = await ready();

      cubit.showStep(-2);
      expect(cubit.state.step, 0);
      cubit.showStep(40);
      expect(cubit.state.step, 4);
    });

    test('does not emit when the step does not change', () async {
      final cubit = await ready();
      final emitted = <RunSheetState>[];
      final sub = cubit.stream.listen(emitted.add);

      cubit.showStep(0);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emitted, isEmpty);
    });
  });

  group('local counters', () {
    test('counts successes up to the number of attempts', () async {
      final cubit = await ready();

      cubit
        ..countChanged('ini', 1)
        ..countChanged('ini', 1)
        ..countChanged('ini', 1);

      expect(cubit.state.counts, {'ini': 2});
    });

    test('never counts below zero', () async {
      final cubit = await ready();

      cubit.countChanged('ini', -1);

      expect(cubit.state.counts, isEmpty);
    });

    test(
      'ignores a counter for a checklist or an unknown initiation',
      () async {
        final cubit = await ready();

        cubit
          ..countChanged('grille', 1)
          ..countChanged('inconnue', 1);

        expect(cubit.state.counts, isEmpty);
      },
    );

    test('ticks and unticks the criteria of a checklist', () async {
      final cubit = await ready();

      cubit
        ..criterionToggled('grille', 1)
        ..criterionToggled('grille', 0);
      expect(cubit.state.checked['grille'], {0, 1});
      cubit.criterionToggled('grille', 1);

      expect(cubit.state.checked['grille'], {0});
    });

    test('keeps a score for each side, never below zero', () async {
      final cubit = await ready();

      cubit
        ..scoreChanged(ScoreSide.a, 1)
        ..scoreChanged(ScoreSide.a, 1)
        ..scoreChanged(ScoreSide.b, 1)
        ..scoreChanged(ScoreSide.b, -1)
        ..scoreChanged(ScoreSide.b, -1);

      expect(cubit.state.scoreA, 2);
      expect(cubit.state.scoreB, 0);
    });
  });

  group('timer', () {
    test('counts the seconds only while running', () async {
      final cubit = await ready();

      ticker.tick(3);
      expect(cubit.state.timerSeconds, 0);
      cubit.timerToggled();
      expect(cubit.state.timerRunning, isTrue);
      ticker.tick(4);
      expect(cubit.state.timerSeconds, 4);
      cubit.timerToggled();
      ticker.tick(5);

      expect(cubit.state.timerRunning, isFalse);
      expect(cubit.state.timerSeconds, 4);
      expect(ticker.hasListener, isFalse);
    });

    test('resets to zero and keeps running', () async {
      final cubit = await ready();
      cubit.timerToggled();
      ticker.tick(10);

      cubit.timerReset();

      expect(cubit.state.timerSeconds, 0);
      expect(cubit.state.timerRunning, isTrue);
    });

    test('starts over when the phase changes', () async {
      final cubit = await ready();
      cubit.timerToggled();
      ticker.tick(10);

      cubit.showStep(1);
      expect(cubit.state.timerSeconds, 0);
      ticker.tick(5);
      cubit.showStep(2);

      expect(cubit.state.timerSeconds, 5);
    });
  });

  group('finish', () {
    test('resets the step, the counters, the score and the timer', () async {
      final cubit = await ready();
      cubit
        ..showStep(2)
        ..countChanged('ini', 1)
        ..criterionToggled('grille', 0)
        ..scoreChanged(ScoreSide.a, 3)
        ..timerToggled();
      ticker.tick(7);

      await cubit.finish();

      expect(cubit.state.status, RunStatus.ready);
      expect(cubit.state.plan, isNotNull);
      expect(cubit.state.step, 0);
      expect(cubit.state.counts, isEmpty);
      expect(cubit.state.checked, isEmpty);
      expect(cubit.state.scoreA, 0);
      expect(cubit.state.timerRunning, isFalse);
      expect(cubit.state.timerSeconds, 0);
      expect(ticker.hasListener, isFalse);
    });

    test('forgets a step asked for before the plan arrived', () async {
      final cubit = build()..showStep(3);

      await cubit.finish();
      await cubit.load();

      expect(cubit.state.step, 0);
    });
  });

  group('syncFromRoute', () {
    test('shows the step of the address and loads the plan', () async {
      final cubit = build();

      await cubit.syncFromRoute(step: 3);

      expect(cubit.state.status, RunStatus.ready);
      expect(cubit.state.step, 3);
      expect(cubit.state.resumeOffered, isFalse);
    });

    test('offers nothing on a fresh launch', () async {
      final cubit = build();

      await cubit.syncFromRoute();

      expect(cubit.state.step, 0);
      expect(cubit.state.resumeOffered, isFalse);
    });

    test('offers to resume a launch that finds progress', () async {
      final cubit = await ready();
      cubit.showStep(2);

      await cubit.syncFromRoute();

      expect(cubit.state.resumeOffered, isTrue);
      expect(cubit.state.step, 2);
    });

    test('offers to resume for counted successes and a score', () async {
      final counted = await ready();
      counted.countChanged('ini', 1);
      await counted.syncFromRoute();
      expect(counted.state.hasProgress, isTrue);
      expect(counted.state.resumeOffered, isTrue);

      final checked = await ready();
      checked.criterionToggled('grille', 0);
      await checked.syncFromRoute();
      expect(checked.state.resumeOffered, isTrue);

      final scored = await ready();
      scored.scoreChanged(ScoreSide.b, 1);
      await scored.syncFromRoute();
      expect(scored.state.resumeOffered, isTrue);
    });

    test('does not count the timer alone as progress', () async {
      final cubit = await ready();
      cubit.timerToggled();
      ticker.tick(5);

      await cubit.syncFromRoute();

      expect(cubit.state.resumeOffered, isFalse);
      await cubit.close();
    });

    test('is idempotent when rebuilt with the same address', () async {
      final cubit = await ready();
      cubit.showStep(2);
      final states = <RunSheetState>[];
      final subscription = cubit.stream.listen(states.add);

      await cubit.syncFromRoute();
      await cubit.syncFromRoute();
      await subscription.cancel();

      expect(states, hasLength(1));
      expect(states.single.resumeOffered, isTrue);
    });

    test('an explicit step settles the offer', () async {
      final cubit = await ready();
      cubit.showStep(2);
      await cubit.syncFromRoute();

      await cubit.syncFromRoute(step: 2);

      expect(cubit.state.resumeOffered, isFalse);
      expect(cubit.state.step, 2);
    });
  });

  group('resume and restart', () {
    test('resume keeps everything and settles the offer', () async {
      final cubit = await ready();
      cubit
        ..showStep(2)
        ..countChanged('ini', 1);
      await cubit.syncFromRoute();

      cubit.resume();

      expect(cubit.state.resumeOffered, isFalse);
      expect(cubit.state.step, 2);
      expect(cubit.state.counts, {'ini': 1});
    });

    test('resume without an offer changes nothing', () async {
      final cubit = await ready();
      final states = <RunSheetState>[];
      final subscription = cubit.stream.listen(states.add);

      cubit.resume();
      await subscription.cancel();

      expect(states, isEmpty);
    });

    test('restart clears step, counters, score and the offer', () async {
      final cubit = await ready();
      cubit
        ..showStep(2)
        ..countChanged('ini', 1)
        ..scoreChanged(ScoreSide.a, 2);
      await cubit.syncFromRoute();

      await cubit.restart();

      expect(cubit.state.step, 0);
      expect(cubit.state.counts, isEmpty);
      expect(cubit.state.scoreA, 0);
      expect(cubit.state.resumeOffered, isFalse);
      expect(cubit.state.status, RunStatus.ready);
    });
  });

  group('timerPaused', () {
    test('stops a running timer and keeps the elapsed time', () async {
      final cubit = await ready();
      cubit.timerToggled();
      ticker.tick(3);

      await cubit.timerPaused();
      ticker.tick(2);

      expect(cubit.state.timerRunning, isFalse);
      expect(cubit.state.timerSeconds, 3);
      expect(ticker.hasListener, isFalse);
    });

    test('does nothing when stopped or closed', () async {
      final cubit = await ready();
      final states = <RunSheetState>[];
      final subscription = cubit.stream.listen(states.add);

      await cubit.timerPaused();
      await subscription.cancel();
      await cubit.close();
      await cubit.timerPaused();

      expect(states, isEmpty);
    });
  });

  test('stops the timer when closed', () async {
    final cubit = await ready();
    cubit.timerToggled();

    await cubit.close();

    expect(ticker.hasListener, isFalse);
  });

  test('does not emit once closed', () async {
    final cubit = build();
    final loading = cubit.load();
    await cubit.close();

    await loading;

    expect(cubit.isClosed, isTrue);
  });

  group('mode', () {
    RunSheetCubit planned() => RunSheetCubit(
      resolve,
      ticker,
      RunKey(sheetId: SheetId('demi-bille-1'), sessionId: 'p1'),
      inMemoryRunProgressKeeper(),
    );

    test('starts in review mode without planned session', () {
      expect(build().state.mode, RunMode.review);
    });

    test('starts in lead mode with a planned session', () {
      expect(planned().state.mode, RunMode.lead);
    });

    test('is changed by modeChanged, once', () async {
      final cubit = build();
      final modes = <RunMode>[];
      final sub = cubit.stream.map((s) => s.mode).listen(modes.add);

      cubit
        ..modeChanged(RunMode.lead)
        ..modeChanged(RunMode.lead);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(cubit.state.mode, RunMode.lead);
      expect(modes, [RunMode.lead]);
    });

    test('is applied by syncFromRoute when the address carries it', () async {
      final cubit = build();

      await cubit.syncFromRoute(step: 1, mode: RunMode.lead);

      expect(cubit.state.mode, RunMode.lead);
    });

    test('is kept by syncFromRoute when the address has none', () async {
      final cubit = build()..modeChanged(RunMode.lead);

      await cubit.syncFromRoute(step: 1);
      await cubit.syncFromRoute(step: 2);

      expect(cubit.state.mode, RunMode.lead);
    });

    test('does not count as progress', () {
      final cubit = build()..modeChanged(RunMode.lead);

      expect(cubit.state.hasProgress, isFalse);
    });

    test('goes back to the default mode when the session ends', () async {
      final cubit = await ready();
      cubit.modeChanged(RunMode.lead);

      await cubit.finish();

      expect(cubit.state.mode, RunMode.review);
    });

    test(
      'is reflected in the address only when it differs from the default',
      () {
        final cubit = build();
        expect(cubit.routeMode, isNull);

        cubit.modeChanged(RunMode.lead);
        expect(cubit.routeMode, RunMode.lead);

        final leading = planned();
        expect(leading.routeMode, isNull);
        leading.modeChanged(RunMode.review);
        expect(leading.routeMode, RunMode.review);
      },
    );
  });

  group('timer stage', () {
    test('counts down the budget of the phase of the current step', () async {
      final cubit = await ready();

      // Accueil : 10 min prévues par le minutage du public enfants.
      final budget = cubit
          .state
          .plan!
          .timing
          .phaseMinutes[cubit.state.currentStep!.phase]!;
      expect(cubit.state.timerRemaining, Duration(minutes: budget));
      expect(cubit.state.timerTone, TimerTone.neutral);

      cubit.timerToggled();
      ticker.tick(budget * 60 - 59);
      expect(cubit.state.timerTone, TimerTone.attention);

      ticker.tick(59);
      expect(cubit.state.timerRemaining, Duration.zero);
      expect(cubit.state.timerTone, TimerTone.attention);

      ticker.tick();
      expect(cubit.state.timerRemaining, const Duration(seconds: -1));
      expect(cubit.state.timerTone, TimerTone.overdue);
      await cubit.close();
    });

    test('is unknown before the plan is loaded', () {
      final cubit = build();

      expect(cubit.state.timerRemaining, isNull);
      expect(cubit.state.timerTone, isNull);
    });
  });
}
