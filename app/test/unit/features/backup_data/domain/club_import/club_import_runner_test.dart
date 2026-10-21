import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../support/fixed_clock.dart';
import '../../../../../support/in_memory_import_daily_ledger.dart';
import '../../../../../support/realistic_backup.dart';
import 'planner_support.dart';

/// Un club qui n'applique que la règle du marqueur : un lot n'est accepté que
/// s'il fait avancer le marqueur de `done` à `done + 1`.
class FakeStore implements ClubImportStore {
  ImportMarker? marker;
  final applied = <int>[];
  final List<ServiceFailure?> script = [];
  int inventories = 0;
  int markerReads = 0;
  ServiceFailure? readFailure;

  /// Appelé après chaque lot accepté (simule un autre appareil).
  void Function()? afterApply;

  @override
  Future<ClubInventory> inventory(String fileId) async {
    inventories++;
    return ClubInventory(marker: marker);
  }

  @override
  Future<ImportMarker?> readMarker(String fileId) async {
    markerReads++;
    final failure = readFailure;
    if (failure != null) throw failure;
    return marker;
  }

  @override
  Future<void> commit(ImportLotCommit commit) async {
    if (script.isNotEmpty) {
      final failure = script.removeAt(0);
      if (failure != null) throw failure;
    }
    final before = marker?.done ?? 0;
    if (commit.marker.done != before + 1) {
      throw const ServiceFailure(ServiceFailureCode.denied, 'marqueur');
    }
    applied.add(commit.lot.index);
    marker = commit.marker;
    afterApply?.call();
  }
}

void main() {
  final backup = RealisticBackup();
  const small = ImportLimits(lotSize: 30);
  final plan = planOf(backup, limits: small);

  Future<ImportRunResult> run(
    FakeStore store,
    ClubImportPlan plan, {
    int? budget,
    ImportDailyLedger? ledger,
  }) async {
    final result = await ClubImportRunner(
      store,
      ledger ??
          InMemoryImportDailyLedger(FixedClock(DateTime.utc(2026, 10, 12))),
    )(plan, role: Role.director, budget: budget);
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('$failure'),
    };
  }

  test('the fixture plan has several lots', () {
    expect(plan.lots.length, greaterThan(2));
  });

  test('writes every lot in order and finishes', () async {
    final store = FakeStore();
    final result = await run(store, plan);
    expect(result.status, ImportRunStatus.completed);
    expect(store.applied, [for (var i = 0; i < plan.lots.length; i++) i]);
    expect(result.doneLots, plan.lots.length);
    expect(result.writes, plan.totalWrites);
    expect(store.marker!.state, ImportState.done);
    expect(store.marker!.planId, plan.planId);
    expect(store.marker!.fileId, plan.fingerprint);
    expect(store.marker!.writes, plan.totalWrites);
    expect(store.marker!.role, Role.director);
  });

  test('the first lot creates the marker, the next ones advance it', () async {
    final created = <bool>[];
    final store = FakeStore();
    final spy = _Spy(store, created);
    await ClubImportRunner(spy, _ledger())(plan, role: Role.director);
    expect(created.first, isTrue);
    expect(created.skip(1).every((c) => !c), isTrue);
  });

  test(
    'an interruption stops at the last finished lot, a resume ends the job',
    () async {
      final store = FakeStore()
        ..script.addAll([
          null,
          null,
          const ServiceFailure(ServiceFailureCode.unavailable),
        ]);
      final first = await run(store, plan);
      expect(first.status, ImportRunStatus.interrupted);
      expect(first.doneLots, 2);
      expect(first.failure!.code, ServiceFailureCode.unavailable);
      final resumed = await run(
        store,
        planOf(
          backup,
          limits: small,
          inventory: ClubInventory(marker: store.marker),
        ),
      );
      expect(resumed.status, ImportRunStatus.completed);
      expect(store.applied, [for (var i = 0; i < plan.lots.length; i++) i]);
    },
  );

  test('a resumed import equals a complete one', () async {
    final complete = FakeStore();
    await run(complete, plan);
    final store = FakeStore()
      ..script.addAll([
        null,
        const ServiceFailure(ServiceFailureCode.unavailable),
      ]);
    await run(store, plan);
    await run(store, plan);
    expect(store.applied, complete.applied);
    expect(store.marker!.done, complete.marker!.done);
  });

  test(
    'an unacknowledged lot that the server did apply is not written twice',
    () async {
      // Le lot 1 est appliqué, l'accusé se perd (unavailable), puis la reprise
      // relit le marqueur : le lot 1 est déjà fait.
      final store = _LostAckStore(lostAt: 1);
      final first = await run(store, plan);
      expect(first.status, ImportRunStatus.interrupted);
      final second = await run(
        store,
        planOf(
          backup,
          limits: small,
          inventory: ClubInventory(marker: store.marker),
        ),
      );
      expect(second.status, ImportRunStatus.completed);
      expect(store.applied.where((i) => i == 1), hasLength(1));
      expect(store.applied, [for (var i = 0; i < plan.lots.length; i++) i]);
    },
  );

  test(
    'a lot refused because the marker already advanced counts as done',
    () async {
      // Un autre appareil (ou la file du SDK) a appliqué le lot 1 entre-temps.
      final store = FakeStore();
      store.afterApply = () {
        if (store.applied.length == 1) {
          store.marker = store.marker!.advanced();
          store.applied.add(1);
          store.afterApply = null;
        }
      };
      final result = await run(store, plan);
      expect(result.status, ImportRunStatus.completed);
      expect(store.applied, [for (var i = 0; i < plan.lots.length; i++) i]);
    },
  );

  test(
    'a refusal of the rules stops the import with the marker unchanged',
    () async {
      final store = FakeStore()
        ..script.addAll([
          null,
          const ServiceFailure(ServiceFailureCode.denied),
        ]);
      final result = await run(store, plan);
      expect(result.status, ImportRunStatus.failed);
      expect(result.failure!.code, ServiceFailureCode.denied);
      expect(result.doneLots, 1);
      expect(store.marker!.done, 1);
      expect(store.markerReads, 1);
    },
  );

  test('a failure to read the marker back is an interruption', () async {
    final store = FakeStore()
      ..script.add(const ServiceFailure(ServiceFailureCode.denied))
      ..readFailure = const ServiceFailure(ServiceFailureCode.unavailable);
    final result = await run(store, plan);
    expect(result.status, ImportRunStatus.interrupted);
  });

  test('any other failure is reported', () async {
    final store = FakeStore()
      ..script.add(const ServiceFailure(ServiceFailureCode.other, 'x'));
    final result = await run(store, plan);
    expect(result.status, ImportRunStatus.failed);
    expect(result.doneLots, 0);
  });

  group('the daily budget is a ceiling, not a target', () {
    // Le coût d'un lot : ses écritures et le marqueur.
    final cost = plan.lots.first.writes.length + 1;

    Future<ImportRunResult> afterSpending(int already, int limit) async {
      final ledger = _ledger();
      await ledger.add(already);
      return await run(FakeStore(), plan, budget: limit, ledger: ledger);
    }

    test('a lot that lands exactly on the ceiling is written', () async {
      final result = await afterSpending(10, 10 + cost);
      // Le premier lot tient au centime près ; le suivant ne tient plus.
      expect(result.doneLots, 1);
      expect(result.writes, plan.lots.first.writes.length);
      expect(result.status, ImportRunStatus.paused);
    });

    test('a lot one write above the ceiling waits for the next day', () async {
      final result = await afterSpending(10, 10 + cost - 1);
      expect(result.status, ImportRunStatus.paused);
      expect(result.writes, 0);
      expect(result.doneLots, 0);
    });

    test('with nothing spent today the first lot is written whatever the '
        'ceiling', () async {
      final result = await afterSpending(0, 1);
      expect(result.writes, greaterThan(0));
    });

    test('the ledger counts exactly what was written', () async {
      final ledger = _ledger();
      await run(FakeStore(), plan, budget: cost, ledger: ledger);
      expect(await ledger.spentToday(), cost);
    });
  });

  group('the daily budget', () {
    test(
      'stops before the lot that would exceed it, and resumes the next day',
      () async {
        const limits = ImportLimits(lotSize: 30, dailyWrites: 60);
        final budgeted = planOf(backup, limits: limits);
        final store = FakeStore();
        final clock = FixedClock(DateTime.utc(2026, 10, 12, 9));
        final ledger = _ledger(clock);
        final first = await run(store, budgeted, ledger: ledger);
        expect(first.status, ImportRunStatus.paused);
        expect(first.doneLots, lessThan(budgeted.lots.length));
        var spent = 0;
        for (final index in store.applied) {
          spent += budgeted.lots[index].writes.length + 1;
        }
        expect(spent, lessThanOrEqualTo(60));
        final days = <int>[first.doneLots];
        var current = first;
        while (current.status == ImportRunStatus.paused) {
          clock.advance(const Duration(days: 1));
          current = await run(
            store,
            planOf(
              backup,
              limits: limits,
              inventory: ClubInventory(marker: store.marker),
            ),
            ledger: ledger,
          );
          days.add(current.doneLots);
        }
        expect(current.status, ImportRunStatus.completed);
        expect(days.length, budgeted.daysNeeded);
        expect(store.applied, [
          for (var i = 0; i < budgeted.lots.length; i++) i,
        ]);
      },
    );

    test(
      'a budget smaller than one lot still writes one lot per day',
      () async {
        final store = FakeStore();
        final clock = FixedClock(DateTime.utc(2026, 10, 12, 9));
        final ledger = _ledger(clock);
        final result = await run(store, plan, budget: 1, ledger: ledger);
        expect(result.status, ImportRunStatus.paused);
        expect(result.doneLots, 1);
        clock.advance(const Duration(days: 1));
        final next = await run(store, plan, budget: 1, ledger: ledger);
        expect(next.doneLots, 2);
      },
    );

    test(
      'two runs the same day never write more than the daily limit',
      () async {
        const limits = ImportLimits(lotSize: 30, dailyWrites: 60);
        final budgeted = planOf(backup, limits: limits);
        final store = FakeStore();
        final ledger = _ledger();
        final first = await run(store, budgeted, ledger: ledger);
        expect(first.status, ImportRunStatus.paused);
        final lotsAfterFirst = store.applied.length;
        // « Reprendre » juste après la pause, le même jour : rien de plus.
        final second = await run(
          store,
          planOf(
            backup,
            limits: limits,
            inventory: ClubInventory(marker: store.marker),
          ),
          ledger: ledger,
        );
        expect(second.status, ImportRunStatus.paused);
        expect(second.writes, 0);
        expect(store.applied, hasLength(lotsAfterFirst));
        var spent = 0;
        for (final index in store.applied) {
          spent += budgeted.lots[index].writes.length + 1;
        }
        expect(spent, lessThanOrEqualTo(60));
      },
    );

    test('a lot left in the SDK queue counts against the day', () async {
      final store = FakeStore()
        ..script.add(const ServiceFailure(ServiceFailureCode.unavailable));
      final ledger = _ledger();
      final result = await run(store, plan, ledger: ledger);
      expect(result.status, ImportRunStatus.interrupted);
      expect(await ledger.spentToday(), plan.lots.first.writes.length + 1);
    });

    test('the count restarts the next day', () async {
      final clock = FixedClock(DateTime.utc(2026, 10, 12, 23, 59));
      final ledger = _ledger(clock);
      await ledger.add(42);
      expect(await ledger.spentToday(), 42);
      clock.advance(const Duration(minutes: 2));
      expect(await ledger.spentToday(), 0);
    });
  });

  group('refusals', () {
    test('a plan that is not runnable is refused without any read', () async {
      final store = FakeStore();
      final blocked = planOf(backup, decisions: ImportDecisions.none);
      final result = await ClubImportRunner(store, _ledger())(
        blocked,
        role: Role.director,
      );
      expect(result, isA<Err<ImportRunResult>>());
      expect(store.inventories, 0);
      expect(store.applied, isEmpty);
    });

    test('a marker of another plan is not resumed', () async {
      final store = FakeStore()
        ..marker = ImportMarker(
          fileId: plan.fingerprint,
          planId: 'f' * 64,
          lots: plan.lots.length,
          done: 1,
          writes: 1,
          restored: 0,
          role: Role.director,
        );
      final result = await ClubImportRunner(store, _ledger())(
        plan,
        role: Role.director,
      );
      expect(result, isA<Ok<ImportRunResult>>());
      expect(
        (result as Ok<ImportRunResult>).value.status,
        ImportRunStatus.planChanged,
      );
      expect(store.applied, isEmpty);
    });

    test('a finished import writes nothing', () async {
      final store = FakeStore();
      await run(store, plan);
      final applied = store.applied.length;
      final again = await run(store, plan);
      expect(again.status, ImportRunStatus.completed);
      expect(again.writes, 0);
      expect(store.applied, hasLength(applied));
    });
  });

  test('progress is reported from the start and after each lot', () async {
    final seen = <(int, int)>[];
    final result = await ClubImportRunner(FakeStore(), _ledger())(
      plan,
      role: Role.director,
      onProgress: (done, total) => seen.add((done, total)),
    );
    expect(
      (result as Ok<ImportRunResult>).value.status,
      ImportRunStatus.completed,
    );
    final total = plan.lots.length;
    expect(seen.first, (0, total));
    expect(seen.last, (total, total));
    expect(seen.length, total + 1);
  });

  test('a stop request is taken between two lots and resumes after', () async {
    final store = FakeStore();
    var asked = false;
    store.afterApply = () => asked = true;
    final runner = ClubImportRunner(store, _ledger());
    final first = await runner(
      plan,
      role: Role.director,
      shouldStop: () => asked,
    );
    final stopped = (first as Ok<ImportRunResult>).value;
    expect(stopped.status, ImportRunStatus.cancelled);
    expect(stopped.doneLots, 1);
    expect(store.applied, [0]);
    final second = await runner(plan, role: Role.director);
    expect(
      (second as Ok<ImportRunResult>).value.status,
      ImportRunStatus.completed,
    );
    expect(store.applied, [for (var i = 0; i < plan.lots.length; i++) i]);
  });

  test('a stop asked before the first lot writes nothing', () async {
    final store = FakeStore();
    final result = await ClubImportRunner(store, _ledger())(
      plan,
      role: Role.director,
      shouldStop: () => true,
    );
    expect(
      (result as Ok<ImportRunResult>).value.status,
      ImportRunStatus.cancelled,
    );
    expect(store.applied, isEmpty);
  });
}

InMemoryImportDailyLedger _ledger([FixedClock? clock]) =>
    InMemoryImportDailyLedger(clock ?? FixedClock(DateTime.utc(2026, 10, 12)));

/// Compte les créations de marqueur.
class _Spy implements ClubImportStore {
  _Spy(this.inner, this.created);

  final FakeStore inner;
  final List<bool> created;

  @override
  Future<ClubInventory> inventory(String fileId) => inner.inventory(fileId);

  @override
  Future<ImportMarker?> readMarker(String fileId) => inner.readMarker(fileId);

  @override
  Future<void> commit(ImportLotCommit commit) {
    created.add(commit.createsMarker);
    return inner.commit(commit);
  }
}

/// Applique le lot [lostAt], puis perd l'accusé.
class _LostAckStore extends FakeStore {
  _LostAckStore({required this.lostAt});

  final int lostAt;
  bool _lost = false;

  @override
  Future<void> commit(ImportLotCommit commit) async {
    await super.commit(commit);
    if (commit.lot.index == lostAt && !_lost) {
      _lost = true;
      throw const ServiceFailure(ServiceFailureCode.unavailable);
    }
  }
}
