import 'dart:async';

import 'package:billard_cfa/entities/run_progress/data/in_memory_run_progress_repository.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/data/in_memory_session_record_repository.dart';
import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_mode.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_progress_keeper.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_ticker.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/domain_world.dart';
import '../../../../support/fixed_clock.dart';
import '../../../../support/fixtures.dart';
import '../../../../support/run_plan_fixture.dart';

class _MockResolve extends Mock implements ResolveRunPlan;

class _FakeTicker implements RunTicker {
  final controller = StreamController<void>.broadcast(sync: true);

  @override
  Stream<void> ticks() => controller.stream;

  void tick([int seconds = 1]) {
    for (var i = 0; i < seconds; i++) {
      controller.add(null);
    }
  }
}

/// Dépôt dont les écritures se font attendre, une à une, pour prouver qu'elles
/// ne se doublent jamais et que la dernière gagne.
class _GatedRepository extends InMemoryRunProgressRepository {
  final gates = <Completer<void>>[];
  int running = 0;
  int maxRunning = 0;

  @override
  Future<void> save(RunProgress progress) async {
    running++;
    if (running > maxRunning) maxRunning = running;
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    await super.save(progress);
    running--;
  }
}

/// Dépôt dont toutes les opérations échouent (disque plein).
class _BrokenRepository extends InMemoryRunProgressRepository {
  @override
  Future<void> save(RunProgress progress) async =>
      throw StateError('disque plein');

  @override
  Future<void> delete(RunProgressKey key) async =>
      throw StateError('disque plein');

  @override
  Future<RunProgress?> byKey(RunProgressKey key) async =>
      throw StateError('disque illisible');
}

/// Saisies dont l'écriture des étiquettes échoue (disque plein).
class _BrokenRecords extends InMemorySessionRecordRepository {
  @override
  Future<void> setTags(SessionId id, Set<SessionTag> tags) async =>
      throw StateError('disque plein');
}

class _ErrorRecorder extends BlocObserver {
  final errors = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  late _MockResolve resolve;
  late _FakeTicker ticker;
  late DomainWorld world;
  late FixedClock clock;
  late InMemoryRunProgressRepository repository;
  final key = RunKey(
    sheetId: SheetId('demi-bille-1'),
    audience: Audience.children,
  );

  RunProgressKeeper keeperOver(RunProgressRepository over) =>
      RunProgressKeeper(over, world.sessions, world.groups, clock);

  RunSheetCubit build({RunProgressRepository? over, RunKey? runKey}) =>
      RunSheetCubit(
        resolve,
        ticker,
        runKey ?? key,
        keeperOver(over ?? repository),
      );

  Future<RunSheetCubit> ready({RunProgressRepository? over}) async {
    final cubit = build(over: over);
    await cubit.load();
    return cubit;
  }

  Future<RunProgress?> stored([RunKey? runKey]) =>
      repository.byKey((runKey ?? key).progressKey);

  setUpAll(() => registerFallbackValue(SheetId('x-1')));
  setUp(() {
    resolve = _MockResolve();
    ticker = _FakeTicker();
    world = DomainWorld();
    clock = FixedClock(DateTime.utc(2026, 10, 16, 9));
    repository = InMemoryRunProgressRepository();
    when(
      () => resolve(
        any(),
        audience: any(named: 'audience'),
        sessionId: any(named: 'sessionId'),
      ),
    ).thenAnswer((_) async => Ok(runPlanFixture()));
  });

  group('session tags (ADR 0023)', () {
    test('are chosen, replaced and cleared one change at a time', () async {
      final cubit = await ready();
      addTearDown(cubit.close);

      cubit.tagsChanged({SessionTag.tooLong});
      expect(cubit.state.tags, {SessionTag.tooLong});
      cubit.tagsChanged({SessionTag.tooLong, SessionTag.toRedo});
      expect(cubit.state.tags, {SessionTag.tooLong, SessionTag.toRedo});
      cubit.tagsChanged(const {});
      expect(cubit.state.tags, isEmpty);
    });

    test('alone are enough to be written with the running session', () async {
      final cubit = await ready();
      addTearDown(cubit.close);

      cubit.tagsChanged({SessionTag.gameAppreciated});
      await pumpEventQueue();

      final saved = (await stored())!;
      expect(saved.tags, {SessionTag.gameAppreciated});
      expect(saved.step, 0);
    });

    test('cleared with nothing else, forget the session', () async {
      final cubit = await ready();
      addTearDown(cubit.close);
      cubit.tagsChanged({SessionTag.gameAppreciated});
      await pumpEventQueue();

      cubit.tagsChanged(const {});
      await pumpEventQueue();

      expect(await stored(), isNull);
    });

    test('are written with the other parts and keep them', () async {
      final cubit = await ready();
      addTearDown(cubit.close);
      cubit
        ..scoreChanged(ScoreSide.a, 3)
        ..tagsChanged({SessionTag.tooHard});
      await pumpEventQueue();

      final saved = (await stored())!;
      expect(saved.scoreA, 3);
      expect(saved.tags, {SessionTag.tooHard});
    });

    test('come back when the session is read again', () async {
      final first = await ready();
      first.tagsChanged({SessionTag.tooEasy, SessionTag.equipmentLacking});
      await pumpEventQueue();
      await first.close();

      final second = build();
      addTearDown(second.close);
      await second.syncFromRoute();

      expect(second.state.tags, {
        SessionTag.tooEasy,
        SessionTag.equipmentLacking,
      });
      expect(second.state.resumeOffered, isTrue);
    });

    test('are forgotten with the session at finish and restart', () async {
      final cubit = await ready();
      addTearDown(cubit.close);
      cubit.tagsChanged({SessionTag.tooLong});
      await pumpEventQueue();

      await cubit.restart();
      await pumpEventQueue();

      expect(cubit.state.tags, isEmpty);
      expect(await stored(), isNull);
    });

    test('restart never gives them to the record', () async {
      await world.session(dayOfMonth: 5);
      final cubit = await ready();
      addTearDown(cubit.close);
      cubit
        ..recordChosen(
          recordId: const SessionId('x1'),
          group: const GroupId('g1'),
          date: day(5),
          absent: const {},
        )
        ..tagsChanged({SessionTag.tooLong});

      await cubit.restart();

      expect((await world.sessions.byId(const SessionId('x1')))!.tags, isEmpty);
    });

    test('end of session gives them to the open record, then resets', () async {
      await world.session(dayOfMonth: 5);
      final cubit = await ready();
      addTearDown(cubit.close);
      cubit
        ..recordChosen(
          recordId: const SessionId('x1'),
          group: const GroupId('g1'),
          date: day(5),
          absent: const {},
        )
        ..tagsChanged({SessionTag.tooLong, SessionTag.toRedo});

      await cubit.endSession();
      await pumpEventQueue();

      expect((await world.sessions.byId(const SessionId('x1')))!.tags, {
        SessionTag.tooLong,
        SessionTag.toRedo,
      });
      expect(cubit.state.tags, isEmpty);
      expect(cubit.state.recordChoice, isNull);
      expect(await stored(), isNull);
    });

    test('end of session without a record keeps nothing anywhere', () async {
      await world.session(dayOfMonth: 5);
      final cubit = await ready();
      addTearDown(cubit.close);
      cubit.tagsChanged({SessionTag.tooLong});

      await cubit.endSession();

      expect((await world.sessions.byId(const SessionId('x1')))!.tags, isEmpty);
      expect(cubit.state.tags, isEmpty);
    });

    test('end of session without tags leaves the record tags alone', () async {
      await world.session(dayOfMonth: 5);
      await world.sessions.setTags(const SessionId('x1'), {SessionTag.toRedo});
      final cubit = await ready();
      addTearDown(cubit.close);
      cubit.recordChosen(
        recordId: const SessionId('x1'),
        group: const GroupId('g1'),
        date: day(5),
        absent: const {},
      );

      await cubit.endSession();

      expect((await world.sessions.byId(const SessionId('x1')))!.tags, {
        SessionTag.toRedo,
      });
    });

    test('a failing record write keeps the session open and says so', () async {
      final failing = _BrokenRecords();
      final cubit = RunSheetCubit(
        resolve,
        ticker,
        key,
        RunProgressKeeper(repository, failing, world.groups, clock),
      );
      addTearDown(cubit.close);
      await cubit.load();
      cubit
        ..recordChosen(
          recordId: const SessionId('x1'),
          group: const GroupId('g1'),
          date: day(5),
          absent: const {},
        )
        ..tagsChanged({SessionTag.tooLong});

      final ended = await cubit.endSession();

      expect(ended, isFalse);
      expect(cubit.state.tagsNotSaved, isTrue);
      expect(cubit.state.tags, {SessionTag.tooLong});
      expect(cubit.state.recordChoice, isNotNull);

      cubit.tagsChanged({SessionTag.tooLong, SessionTag.toRedo});
      expect(cubit.state.tagsNotSaved, isFalse);
    });

    test('a successful end of session reports it ended', () async {
      await world.session(dayOfMonth: 5);
      final cubit = await ready();
      addTearDown(cubit.close);

      expect(await cubit.endSession(), isTrue);
    });

    test('discard gives nothing to the open record', () async {
      await world.session(dayOfMonth: 5);
      final cubit = await ready();
      addTearDown(cubit.close);
      cubit
        ..recordChosen(
          recordId: const SessionId('x1'),
          group: const GroupId('g1'),
          date: day(5),
          absent: const {},
        )
        ..tagsChanged({SessionTag.tooLong});
      await pumpEventQueue();

      await cubit.discard();

      expect(await stored(), isNull);
      expect((await world.sessions.byId(const SessionId('x1')))!.tags, isEmpty);
    });
  });

  group('writing', () {
    test('writes nothing for a session without progress', () async {
      final cubit = await ready();
      await pumpEventQueue();

      expect(await repository.all(), isEmpty);
      await cubit.close();
    });

    test('writes the step as soon as it moves past the first', () async {
      final cubit = await ready()
        ..showStep(2);
      await pumpEventQueue();

      expect((await stored())!.step, 2);
      expect((await stored())!.updatedAt, clock.now());
      await cubit.close();
    });

    test('writes the counters', () async {
      final cubit = await ready()
        ..countChanged('ini', 1)
        ..countChanged('ini', 1);
      await pumpEventQueue();

      expect((await stored())!.counts, {'ini': 2});
      await cubit.close();
    });

    test('writes the ticked criteria', () async {
      final cubit = await ready()
        ..criterionToggled('grille', 1)
        ..criterionToggled('grille', 0);
      await pumpEventQueue();

      expect((await stored())!.checked, {
        'grille': {0, 1},
      });
      await cubit.close();
    });

    test('writes the score of both sides', () async {
      final cubit = await ready()
        ..scoreChanged(ScoreSide.a, 1)
        ..scoreChanged(ScoreSide.a, 1)
        ..scoreChanged(ScoreSide.b, 1);
      await pumpEventQueue();

      expect((await stored())!.scoreA, 2);
      expect((await stored())!.scoreB, 1);
      await cubit.close();
    });

    test(
      'forgets the session when its progress goes back to nothing',
      () async {
        final cubit = await ready()
          ..countChanged('ini', 1);
        await pumpEventQueue();
        expect(await stored(), isNotNull);

        cubit.countChanged('ini', -1);
        await pumpEventQueue();

        expect(await stored(), isNull);
        await cubit.close();
      },
    );

    test(
      'does not write for a change of mode or of the resume offer',
      () async {
        final cubit = await ready()
          ..showStep(2);
        await pumpEventQueue();
        clock.advance(const Duration(minutes: 5));

        cubit
          ..modeChanged(RunMode.lead)
          ..resume();
        await cubit.syncFromRoute();
        await pumpEventQueue();

        expect((await stored())!.updatedAt, DateTime.utc(2026, 10, 16, 9));
        await cubit.close();
      },
    );

    test(
      'writes the record that was opened, and only its identifier',
      () async {
        final cubit = await ready()
          ..showStep(2)
          ..recordChosen(
            recordId: const SessionId('x1'),
            group: const GroupId('g1'),
            date: day(5),
            absent: {const StudentId('s2')},
          );
        await pumpEventQueue();

        final saved = (await stored())!;
        expect(saved.recordId, const SessionId('x1'));
        expect(saved.key.groupId, isNull);
        await cubit.close();
      },
    );

    test('keeps the progress when the cubit is closed', () async {
      final cubit = await ready()
        ..countChanged('ini', 1);
      await pumpEventQueue();

      await cubit.close();

      expect((await stored())!.counts, {'ini': 1});
    });

    test('writes the key of a planned session and of a group', () async {
      final runKey = RunKey(
        sheetId: SheetId('demi-bille-1'),
        audience: Audience.adults,
        sessionId: 'p1',
        group: const GroupId('g1'),
      );
      final cubit = build(runKey: runKey);
      await cubit.load();
      cubit.showStep(1);
      await pumpEventQueue();

      final saved = (await stored(runKey))!;
      expect(saved.key.sessionId, 'p1');
      expect(saved.key.groupId, const GroupId('g1'));
      expect(saved.key.audience, Audience.adults);
      await cubit.close();
    });
  });

  group('the timer', () {
    Future<RunSheetCubit> started() async {
      final cubit = await ready()
        ..showStep(2) // progression : le minuteur seul n'en est pas une
        ..timerToggled();
      await pumpEventQueue();
      return cubit;
    }

    test('is written every ten seconds, not in between', () async {
      final cubit = await started();

      ticker.tick(9);
      await pumpEventQueue();
      expect((await stored())!.timerSeconds, 0);

      ticker.tick();
      await pumpEventQueue();
      expect((await stored())!.timerSeconds, 10);

      ticker.tick(3);
      await pumpEventQueue();
      expect((await stored())!.timerSeconds, 10);

      ticker.tick(7);
      await pumpEventQueue();
      expect((await stored())!.timerSeconds, 20);
      await cubit.close();
    });

    test('is written exactly when paused', () async {
      final cubit = await started();
      ticker.tick(13);

      cubit.timerToggled();
      await pumpEventQueue();

      expect((await stored())!.timerSeconds, 13);
      await cubit.close();
    });

    test('is written exactly when the guide is left while it runs', () async {
      final cubit = await started();
      ticker.tick(7);

      await cubit.timerPaused();
      await pumpEventQueue();

      expect((await stored())!.timerSeconds, 7);
      await cubit.close();
    });

    test('is written at zero when reset', () async {
      final cubit = await started();
      ticker.tick(15);
      await pumpEventQueue();

      cubit.timerReset();
      await pumpEventQueue();

      expect((await stored())!.timerSeconds, 0);
      await cubit.close();
    });

    test('is written at zero when the phase changes', () async {
      final cubit = await started();
      ticker.tick(15);
      await pumpEventQueue();

      cubit.showStep(3); // autre phase : le minuteur repart de zéro
      await pumpEventQueue();

      final saved = (await stored())!;
      expect(saved.step, 3);
      expect(saved.timerSeconds, 0);
      await cubit.close();
    });

    test('alone is not progress: nothing is written', () async {
      final cubit = await ready()
        ..timerToggled();
      ticker.tick(30);
      await pumpEventQueue();

      expect(await repository.all(), isEmpty);
      await cubit.close();
    });
  });

  group('forgetting', () {
    Future<RunSheetCubit> withProgress() async {
      final cubit = await ready()
        ..showStep(2)
        ..countChanged('ini', 1);
      await pumpEventQueue();
      expect(await stored(), isNotNull);
      return cubit;
    }

    test('finish forgets the session', () async {
      final cubit = await withProgress();

      await cubit.finish();
      await pumpEventQueue();

      expect(await stored(), isNull);
      await cubit.close();
    });

    test('restart forgets the session', () async {
      final cubit = await withProgress();

      await cubit.restart();
      await pumpEventQueue();

      expect(await stored(), isNull);
      await cubit.close();
    });

    test('discard forgets the session without touching the state', () async {
      final cubit = await withProgress();

      await cubit.discard();

      expect(await stored(), isNull);
      expect(cubit.state.counts, {'ini': 1});
      await cubit.close();
    });
  });

  group('writes are serialised', () {
    test('two slow writes never overlap and the last one wins', () async {
      final slow = _GatedRepository();
      final cubit = await ready(over: slow)
        ..showStep(2)
        ..showStep(3);
      await pumpEventQueue();
      expect(slow.gates, hasLength(1), reason: 'la seconde écriture attend');

      slow.gates.first.complete();
      await pumpEventQueue();
      expect(slow.gates, hasLength(2));
      slow.gates.last.complete();
      await pumpEventQueue();

      expect(slow.maxRunning, 1);
      expect((await slow.byKey(key.progressKey))!.step, 3);
      await cubit.close();
    });

    test('a write asked before close still completes after it', () async {
      final slow = _GatedRepository();
      final cubit = await ready(over: slow)
        ..showStep(2);
      await pumpEventQueue();

      await cubit.close();
      slow.gates.single.complete();
      await pumpEventQueue();

      expect(cubit.isClosed, isTrue);
      expect((await slow.byKey(key.progressKey))!.step, 2);
    });
  });

  group('forgetting by force', () {
    test(
      'discard waits for the write in flight, then the row is gone',
      () async {
        final slow = _GatedRepository();
        final cubit = await ready(over: slow)
          ..showStep(2);
        await pumpEventQueue();

        var done = false;
        final discarding = cubit.discard().whenComplete(() => done = true);
        await pumpEventQueue();
        expect(done, isFalse, reason: 'l écriture en vol n est pas finie');

        slow.gates.single.complete();
        await discarding;

        expect(await slow.byKey(key.progressKey), isNull);
        await cubit.close();
      },
    );

    test('erase forgets the row after the write in flight and accepts no '
        'other write', () async {
      final slow = _GatedRepository();
      final cubit = await ready(over: slow)
        ..showStep(2);
      await pumpEventQueue();

      final erasing = cubit.erase();
      cubit.showStep(3);
      slow.gates.single.complete();
      await erasing;
      await pumpEventQueue();

      expect(slow.gates, hasLength(1), reason: 'pas de seconde écriture');
      expect(await slow.byKey(key.progressKey), isNull);
      await cubit.close();
    });

    test('erase leaves nothing to rewrite on later changes', () async {
      final cubit = await ready()
        ..showStep(2);
      await pumpEventQueue();
      expect(await stored(), isNotNull);

      await cubit.erase();
      cubit
        ..showStep(3)
        ..scoreChanged(ScoreSide.a, 1);
      await pumpEventQueue();

      expect(await stored(), isNull);
      await cubit.close();
    });
  });

  group('a failing disk', () {
    late _ErrorRecorder observer;
    late BlocObserver previous;

    setUp(() {
      previous = Bloc.observer;
      observer = _ErrorRecorder();
      Bloc.observer = observer;
    });
    tearDown(() => Bloc.observer = previous);

    test('never blocks the guide and is reported', () async {
      final cubit = await ready(over: _BrokenRepository());

      cubit
        ..showStep(2)
        ..countChanged('ini', 1);
      await pumpEventQueue();

      expect(cubit.state.step, 2);
      expect(cubit.state.counts, {'ini': 1});
      expect(observer.errors, isNotEmpty);
      await cubit.close();
    });

    test('loads the guide even if the saved state cannot be read', () async {
      final cubit = build(over: _BrokenRepository());

      await cubit.syncFromRoute();

      expect(cubit.state.status, RunStatus.ready);
      expect(cubit.state.hasProgress, isFalse);
      await cubit.close();
    });
  });

  group('restoring', () {
    Future<void> saveRow({
      int step = 3,
      Map<String, int> counts = const {'ini': 2},
      Map<String, Set<int>> checked = const {
        'grille': {1},
      },
      int scoreA = 4,
      int scoreB = 5,
      int timerSeconds = 40,
      SessionId? recordId,
    }) => repository.save(
      RunProgress(
        key: key.progressKey,
        updatedAt: DateTime.utc(2026, 10, 15, 9),
        step: step,
        counts: counts,
        checked: checked,
        scoreA: scoreA,
        scoreB: scoreB,
        timerSeconds: timerSeconds,
        recordId: recordId,
      ),
    );

    test(
      'brings back the step, counters, grid, score and timer, paused',
      () async {
        await saveRow();
        final cubit = build();

        await cubit.load();

        expect(cubit.state.status, RunStatus.ready);
        expect(cubit.state.step, 3);
        expect(cubit.state.counts, {'ini': 2});
        expect(cubit.state.checked, {
          'grille': {1},
        });
        expect(cubit.state.scoreA, 4);
        expect(cubit.state.scoreB, 5);
        expect(cubit.state.timerSeconds, 40);
        expect(cubit.state.timerRunning, isFalse);
        await cubit.close();
      },
    );

    test('offers to resume when the address names no step', () async {
      await saveRow();
      final cubit = build();

      await cubit.syncFromRoute();

      expect(cubit.state.resumeOffered, isTrue);
      expect(cubit.state.step, 3);
      await cubit.close();
    });

    test('the step of the address wins and the counters are kept', () async {
      await saveRow();
      final cubit = build();

      await cubit.syncFromRoute(step: 1);

      expect(cubit.state.step, 1);
      expect(cubit.state.resumeOffered, isFalse);
      expect(cubit.state.counts, {'ini': 2});
      expect(cubit.state.scoreB, 5);
      await cubit.close();
    });

    test('offers nothing when no state was saved', () async {
      final cubit = build();

      await cubit.syncFromRoute();

      expect(cubit.state.resumeOffered, isFalse);
      await cubit.close();
    });

    test(
      'is not a change: nothing is written back when all is consistent',
      () async {
        await saveRow();
        final cubit = build();

        await cubit.syncFromRoute();
        await pumpEventQueue();

        expect((await stored())!.updatedAt, DateTime.utc(2026, 10, 15, 9));
        await cubit.close();
      },
    );

    test(
      'brings a saved step past the end back to the last step, and writes it',
      () async {
        await saveRow(step: 9);
        final cubit = build();

        await cubit.load();
        await pumpEventQueue();

        expect(cubit.state.step, 4);
        expect((await stored())!.step, 4);
        await cubit.close();
      },
    );

    test('drops what the session no longer has, and writes it', () async {
      await saveRow(
        counts: {'ini': 9, 'disparue': 1},
        checked: {
          'grille': {0, 7},
        },
      );
      final cubit = build();

      await cubit.load();
      await pumpEventQueue();

      expect(cubit.state.counts, {'ini': 2});
      expect(cubit.state.checked, {
        'grille': {0},
      });
      final saved = (await stored())!;
      expect(saved.counts, {'ini': 2});
      expect(saved.checked, {
        'grille': {0},
      });
      await cubit.close();
    });

    test('forgets a session whose plan is gone', () async {
      await saveRow();
      when(
        () => resolve(
          any(),
          audience: any(named: 'audience'),
          sessionId: any(named: 'sessionId'),
        ),
      ).thenAnswer((_) async => const Err(NotFound('session', 'p1')));
      final cubit = build();

      await cubit.load();
      await pumpEventQueue();

      expect(cubit.state.status, RunStatus.notFound);
      expect(await stored(), isNull);
      await cubit.close();
    });

    test(
      'forgets the state when nothing is left to resume after reconciling',
      () async {
        await saveRow(
          step: 0,
          counts: {'disparue': 3},
          checked: {},
          scoreA: 0,
          scoreB: 0,
          timerSeconds: 0,
        );
        final cubit = build();

        await cubit.syncFromRoute();
        await pumpEventQueue();

        expect(cubit.state.hasProgress, isFalse);
        expect(cubit.state.resumeOffered, isFalse);
        expect(await stored(), isNull);
        await cubit.close();
      },
    );

    group('a planned session that no longer exists', () {
      final plannedKey = RunKey(
        sheetId: SheetId('demi-bille-1'),
        audience: Audience.children,
        sessionId: 'p1',
      );

      Future<void> saveForPlanned() => repository.save(
        RunProgress(
          key: plannedKey.progressKey,
          updatedAt: DateTime.utc(2026, 10, 15, 9),
          step: 3,
          counts: const {'ini': 2},
          scoreA: 4,
        ),
      );

      test(
        'is not resumed: the guide starts afresh and the state is forgotten',
        () async {
          await saveForPlanned();
          // Le déroulé se résout sans séance planifiée (supprimée entre-temps).
          final cubit = build(runKey: plannedKey);

          await cubit.syncFromRoute();
          await pumpEventQueue();

          expect(cubit.state.status, RunStatus.ready);
          expect(cubit.state.hasProgress, isFalse);
          expect(cubit.state.step, 0);
          expect(cubit.state.resumeOffered, isFalse);
          expect(await stored(plannedKey), isNull);
          await cubit.close();
        },
      );

      test('still takes the step of the address', () async {
        await saveForPlanned();
        final cubit = build(runKey: plannedKey);

        await cubit.syncFromRoute(step: 2);
        await pumpEventQueue();

        expect(cubit.state.step, 2);
        expect(cubit.state.counts, isEmpty);
        expect((await stored(plannedKey))!.counts, isEmpty);
        await cubit.close();
      });

      test('is resumed when the planned session is still there', () async {
        await saveForPlanned();
        when(
          () => resolve(
            any(),
            audience: any(named: 'audience'),
            sessionId: any(named: 'sessionId'),
          ),
        ).thenAnswer(
          (_) async => Ok(
            runPlanFixture().copyWith(
              planned: Session(
                id: 'p1',
                title: 'Cours',
                date: day(14),
                audience: Audience.children,
              ),
            ),
          ),
        );
        final cubit = build(runKey: plannedKey);

        await cubit.syncFromRoute();

        expect(cubit.state.step, 3);
        expect(cubit.state.counts, {'ini': 2});
        expect(cubit.state.resumeOffered, isTrue);
        await cubit.close();
      });
    });

    group('the record', () {
      setUp(() async {
        await world.seedClub(studentNames: ['s1', 's2']);
        await world.session(dayOfMonth: 5);
      });

      RunSheetCubit buildWithWorld() => RunSheetCubit(
        resolve,
        ticker,
        key,
        RunProgressKeeper(repository, world.sessions, world.groups, clock),
      );

      test('is read back from the record, with its absent students', () async {
        await saveRow(recordId: const SessionId('x1'));
        final cubit = buildWithWorld();

        await cubit.load();

        final choice = cubit.state.recordChoice!;
        expect(choice.recordId, const SessionId('x1'));
        expect(choice.group, const GroupId('g1'));
        expect(choice.date, day(5));
        expect(choice.absent, {const StudentId('s2')});
        await cubit.close();
      });

      test(
        'is dropped, and the row rewritten, when the record is gone',
        () async {
          await saveRow(recordId: const SessionId('ghost'));
          final cubit = buildWithWorld();

          await cubit.load();
          await pumpEventQueue();

          expect(cubit.state.recordChoice, isNull);
          expect((await stored())!.recordId, isNull);
          expect((await stored())!.step, 3);
          await cubit.close();
        },
      );
    });
  });
}
