import 'dart:async';

import 'package:billard_cfa/entities/group/data/in_memory_group_repository.dart';
import 'package:billard_cfa/entities/run_progress/data/in_memory_run_progress_repository.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/entities/session_record/data/in_memory_session_record_repository.dart';
import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_progress_keeper.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_ticker.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/running_sessions_cubit.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixed_clock.dart';
import '../../../../support/run_plan_fixture.dart';

class _MockResolve extends Mock implements ResolveRunPlan;

/// Dépôt dont la lecture attend le feu vert du test.
class _GatedReadRepository extends InMemoryRunProgressRepository {
  final gate = Completer<void>();

  @override
  Future<List<RunProgress>> all() async {
    await gate.future;
    return await super.all();
  }
}

/// Dépôt dont la lecture d'une progression attend le feu vert du test.
class _GatedKeyRepository extends InMemoryRunProgressRepository {
  final gate = Completer<void>();

  @override
  Future<RunProgress?> byKey(RunProgressKey key) async {
    await gate.future;
    return await super.byKey(key);
  }
}

/// Dépôt dont la lecture échoue : le démarrage ne doit pas s'en ressentir.
class _UnreadableRepository extends InMemoryRunProgressRepository {
  @override
  Future<List<RunProgress>> all() async => throw StateError('illisible');
}

void main() {
  late _MockResolve resolve;
  late InMemoryRunProgressRepository repository;
  late FixedClock clock;
  late RunSheetSessions sessions;
  final now = DateTime.utc(2026, 10, 16, 9);

  RunKey keyOf(String sheet) =>
      RunKey(sheetId: SheetId(sheet), audience: Audience.children);

  Future<void> saveRow(String sheet, {Duration age = Duration.zero}) =>
      repository.save(
        RunProgress(
          key: keyOf(sheet).progressKey,
          updatedAt: now.subtract(age),
          step: 2,
          counts: const {'ini': 1},
        ),
      );

  RunSheetSessions build([InMemoryRunProgressRepository? over]) =>
      RunSheetSessions(
        resolve,
        PeriodicRunTicker(),
        RunProgressKeeper(
          over ?? repository,
          InMemorySessionRecordRepository(),
          InMemoryGroupRepository(),
          clock,
        ),
      );

  setUpAll(() => registerFallbackValue(SheetId('x-1')));
  setUp(() {
    resolve = _MockResolve();
    repository = InMemoryRunProgressRepository();
    clock = FixedClock(now);
    when(
      () => resolve(
        any(),
        audience: any(named: 'audience'),
        sessionId: any(named: 'sessionId'),
      ),
    ).thenAnswer((_) async => Ok(runPlanFixture()));
    sessions = build();
  });
  tearDown(() => sessions.dispose());

  group('restore', () {
    test('brings back the saved sessions, ready, oldest first', () async {
      await saveRow('a-1', age: const Duration(hours: 3));
      await saveRow('b-1', age: const Duration(hours: 1));

      await sessions.restore();

      expect(sessions.runningKeys, [keyOf('a-1'), keyOf('b-1')]);
      expect(sessions.of(keyOf('a-1')).state.status, RunStatus.ready);
      expect(sessions.of(keyOf('a-1')).state.counts, {'ini': 1});
      // Les plus récentes d'abord dans la liste d'Aujourd'hui.
      expect(sessions.snapshot().map((s) => s.key.sheetId.value), [
        'a-1',
        'b-1',
      ]);
    });

    test('with nothing saved leaves the registry empty', () async {
      await sessions.restore();

      expect(sessions.runningKeys, isEmpty);
    });

    test('forgets what is older than seven days', () async {
      await saveRow('vieille-1', age: const Duration(days: 7, seconds: 1));
      await saveRow('recente-1', age: const Duration(days: 6));

      await sessions.restore();

      expect(sessions.runningKeys, [keyOf('recente-1')]);
      expect(await repository.byKey(keyOf('vieille-1').progressKey), isNull);
    });

    test('keeps the four most recent and forgets the others', () async {
      for (var i = 1; i <= 6; i++) {
        await saveRow('fiche-$i', age: Duration(hours: 10 - i));
      }

      await sessions.restore();

      expect(sessions.runningKeys.map((k) => k.sheetId.value), [
        'fiche-3',
        'fiche-4',
        'fiche-5',
        'fiche-6',
      ]);
      expect(await repository.all(), hasLength(4));
    });

    test('drops a session whose plan is gone and forgets its state', () async {
      await saveRow('a-1');
      await saveRow('disparue-1', age: const Duration(hours: 1));
      when(
        () => resolve(
          SheetId('disparue-1'),
          audience: any(named: 'audience'),
          sessionId: any(named: 'sessionId'),
        ),
      ).thenAnswer((_) async => const Err(NotFound('sheet', 'disparue-1')));

      await sessions.restore();

      expect(sessions.runningKeys, [keyOf('a-1')]);
      expect(await repository.byKey(keyOf('disparue-1').progressKey), isNull);
    });

    test(
      'drops a session launched from a planned session that is gone',
      () async {
        final planned = RunKey(
          sheetId: SheetId('a-1'),
          audience: Audience.children,
          sessionId: 'p-supprimee',
        );
        await repository.save(
          RunProgress(
            key: planned.progressKey,
            updatedAt: now,
            step: 2,
            counts: const {'ini': 1},
          ),
        );
        await saveRow('b-1', age: const Duration(hours: 1));

        await sessions.restore();

        expect(sessions.runningKeys, [keyOf('b-1')]);
        expect(await repository.byKey(planned.progressKey), isNull);
      },
    );

    test(
      'shares one cubit with a route that asked for the key first',
      () async {
        await saveRow('a-1');

        final restoring = sessions.restore();
        final fromRoute = sessions.of(keyOf('a-1'));
        await restoring;

        expect(sessions.runningKeys, [keyOf('a-1')]);
        expect(sessions.of(keyOf('a-1')), same(fromRoute));
        // La route charge son guide : il relit lui-même l'état enregistré.
        await fromRoute.load();
        expect(fromRoute.state.status, RunStatus.ready);
        expect(fromRoute.state.counts, {'ini': 1});
      },
    );

    test('never evicts an open session, forgets the oldest saved', () async {
      for (var i = 1; i <= 4; i++) {
        await saveRow('fiche-$i', age: Duration(hours: 10 - i));
      }
      final restoring = sessions.restore();
      final opened = sessions.of(keyOf('nouvelle-1'));
      await restoring;

      expect(opened.isClosed, isFalse);
      // La séance ouverte reste la plus récente ; les restaurées la précèdent.
      expect(sessions.runningKeys.map((k) => k.sheetId.value), [
        'fiche-2',
        'fiche-3',
        'fiche-4',
        'nouvelle-1',
      ]);
      expect(await repository.byKey(keyOf('fiche-1').progressKey), isNull);
    });

    test('runs only once', () async {
      await saveRow('a-1');
      await sessions.restore();
      await saveRow('b-1');

      await sessions.restore();

      expect(sessions.runningKeys, [keyOf('a-1')]);
    });

    test('can run again after the sessions were disposed', () async {
      await saveRow('a-1');
      await sessions.restore();
      await sessions.dispose();
      expect(sessions.runningKeys, isEmpty);

      await sessions.restore();

      expect(sessions.runningKeys, [keyOf('a-1')]);
    });

    test('is not an error when the saved state cannot be read, and the cause '
        'is reported', () async {
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);
      final broken = build(_UnreadableRepository());

      await broken.restore();

      expect(broken.runningKeys, isEmpty);
      expect(reported, hasLength(1));
      expect(reported.single.exception, isA<StateError>());
      await broken.dispose();
    });

    test('keeps a session of exactly seven days', () async {
      await saveRow('juste-1', age: const Duration(days: 7));

      await sessions.restore();

      expect(sessions.runningKeys, [keyOf('juste-1')]);
    });

    test('with five saved, forgets only the oldest', () async {
      for (var i = 1; i <= 5; i++) {
        await saveRow('fiche-$i', age: Duration(hours: 10 - i));
      }

      await sessions.restore();

      expect(sessions.runningKeys.map((k) => k.sheetId.value), [
        'fiche-2',
        'fiche-3',
        'fiche-4',
        'fiche-5',
      ]);
      expect(await repository.byKey(keyOf('fiche-1').progressKey), isNull);
    });

    test('a dispose during the restoration waits for it, then leaves the '
        'registry empty', () async {
      await saveRow('a-1');
      final gated = _GatedReadRepository();
      await gated.save(
        RunProgress(
          key: keyOf('a-1').progressKey,
          updatedAt: now,
          step: 2,
          counts: const {'ini': 1},
        ),
      );
      final slow = build(gated);

      final restoring = slow.restore();
      final disposing = slow.dispose();
      gated.gate.complete();
      await restoring;
      await disposing;

      expect(slow.runningKeys, isEmpty);
    });

    test('a guide evicted before it was read is not touched again, and a '
        'new guide of the same key stays', () async {
      final slow = _GatedKeyRepository();
      for (var i = 1; i <= 4; i++) {
        await slow.save(
          RunProgress(
            key: keyOf('fiche-$i').progressKey,
            updatedAt: now.subtract(Duration(hours: 10 - i)),
            step: 2,
            counts: const {'ini': 1},
          ),
        );
      }
      final guarded = build(slow);

      final restoring = guarded.restore();
      await pumpEventQueue();
      // Une cinquième séance évince la plus ancienne restaurée, dont la clé
      // est reprise aussitôt par un nouveau guide.
      guarded.of(keyOf('nouvelle-1'));
      final again = guarded.of(keyOf('fiche-1'));
      slow.gate.complete();
      await restoring;

      expect(guarded.runningKeys, contains(keyOf('fiche-1')));
      expect(guarded.of(keyOf('fiche-1')), same(again));
      expect(again.isClosed, isFalse);
      await guarded.dispose();
    });
  });

  group('erasing a student', () {
    final groupKey = RunKey(
      sheetId: SheetId('a-1'),
      audience: Audience.children,
      group: const GroupId('g1'),
    );
    final plannedKey = RunKey(
      sheetId: SheetId('b-1'),
      audience: Audience.children,
      sessionId: 'p1',
    );

    Future<RunSheetCubit> started(RunKey key) async {
      final cubit = sessions.of(key);
      await cubit.load();
      cubit.showStep(2);
      await pumpEventQueue();
      return cubit;
    }

    test('releases the guides of an erased group, planned session or record, '
        'and keeps the others', () async {
      final byGroup = await started(groupKey);
      final byPlanned = await started(plannedKey);
      final byRecord = await started(keyOf('c-1'));
      byRecord.recordChosen(
        recordId: const SessionId('x1'),
        group: const GroupId('g9'),
        date: DateTime(2026, 10, 12),
        absent: const {},
      );
      final other = await started(keyOf('d-1'));
      await pumpEventQueue();

      await repository.eraseLinked(
        groups: {const GroupId('g1')},
        records: {const SessionId('x1')},
        plannedSessions: {'p1'},
      );
      await pumpEventQueue();

      expect(sessions.runningKeys, [keyOf('d-1')]);
      expect(byGroup.isClosed, isTrue);
      expect(byPlanned.isClosed, isTrue);
      expect(byRecord.isClosed, isTrue);
      expect(other.isClosed, isFalse);
      expect((await repository.all()).map((p) => p.key.sheetId.value), ['d-1']);
    });

    test(
      'an erased guide cannot rewrite its row, even from the list',
      () async {
        await started(groupKey);
        final list = RunningSessionsCubit(sessions);

        await repository.eraseLinked(groups: {const GroupId('g1')});
        await pumpEventQueue();
        list.refresh();

        expect(list.state, isEmpty);
        expect(await repository.all(), isEmpty);
        await list.close();
      },
    );

    test(
      'still releases the guides after a dispose and a new restoration',
      () async {
        await sessions.dispose();
        await sessions.restore();
        await started(groupKey);

        await repository.eraseLinked(groups: {const GroupId('g1')});
        await pumpEventQueue();

        expect(sessions.runningKeys, isEmpty);
        expect(await repository.all(), isEmpty);
      },
    );

    test('forgets a row written by a write that was still in flight', () async {
      final guide = await started(groupKey);
      guide.scoreChanged(ScoreSide.a, 1);

      await repository.eraseLinked(groups: {const GroupId('g1')});
      await pumpEventQueue();

      expect(await repository.all(), isEmpty);
    });
  });

  group('keeping or forgetting the saved state', () {
    Future<RunSheetCubit> started(String sheet) async {
      final cubit = sessions.of(keyOf(sheet));
      await cubit.load();
      cubit.showStep(2);
      await pumpEventQueue();
      return cubit;
    }

    test('release forgets the saved state', () async {
      await started('a-1');
      expect(await repository.all(), hasLength(1));

      await sessions.release(keyOf('a-1'));

      expect(await repository.all(), isEmpty);
    });

    test('evicting the oldest session forgets its saved state', () async {
      await started('fiche-0');
      for (var i = 1; i <= RunSheetSessions.maxRunning; i++) {
        sessions.of(keyOf('fiche-$i'));
      }
      await pumpEventQueue();

      expect(await repository.byKey(keyOf('fiche-0').progressKey), isNull);
    });

    test('dispose keeps the saved state for the next launch', () async {
      await started('a-1');

      await sessions.dispose();

      expect(await repository.all(), hasLength(1));
    });
  });

  group('the Today list', () {
    test('waits for the restoration before showing the sessions', () async {
      await saveRow('a-1');
      final list = RunningSessionsCubit(sessions);

      final restoring = sessions.restore();
      list.refresh();
      expect(list.state, isEmpty, reason: 'pas de liste incomplète');
      await restoring;
      await pumpEventQueue();

      expect(list.state.map((s) => s.key), [keyOf('a-1')]);
      await list.close();
    });

    test('reads the registry at once when nothing is being restored', () async {
      final guide = sessions.of(keyOf('a-1'));
      await guide.load();
      guide.showStep(2);
      final list = RunningSessionsCubit(sessions)..refresh();

      expect(list.state.map((s) => s.key), [keyOf('a-1')]);
      await list.close();
    });
  });

  test('a restored key keeps every part of the saved one', () {
    final full = RunKey(
      sheetId: SheetId('a-1'),
      audience: Audience.adults,
      sessionId: 'p1',
      group: const GroupId('g1'),
    );

    final restored = RunKey.fromProgress(full.progressKey);

    expect(restored, full);
    expect(restored.audience, Audience.adults);
    expect(restored.sessionId, 'p1');
    expect(restored.group, const GroupId('g1'));
    expect(RunKey.fromProgress(keyOf('a-1').progressKey), keyOf('a-1'));
  });

  test('restores a session launched for a group, under its own key', () async {
    final forGroup = RunKey(
      sheetId: SheetId('a-1'),
      audience: Audience.children,
      group: const GroupId('g1'),
    );
    await repository.save(
      RunProgress(
        key: forGroup.progressKey,
        updatedAt: now,
        step: 2,
        counts: const {'ini': 1},
      ),
    );

    await sessions.restore();

    expect(sessions.runningKeys, [forGroup]);
    expect(sessions.snapshot().single.key.group, const GroupId('g1'));
  });
}
