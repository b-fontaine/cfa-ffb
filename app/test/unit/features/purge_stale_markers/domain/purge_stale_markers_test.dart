import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/features/purge_stale_markers/domain/purge_stale_markers.dart';
import 'package:billard_cfa/features/purge_stale_markers/domain/stale_markers.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_plan.dart';
import 'package:billard_cfa/shared/lib/operations/own_marker_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixed_clock.dart';
import '../../../../support/in_memory_write_ledger.dart';

/// Un magasin scripté : les marqueurs anciens rendus par nature, et chaque
/// appel noté.
class _Store implements StaleMarkerStore {
  _Store({
    this.imports = 0,
    this.operations = 0,
    this.failOnDelete,
    this.failOnList,
  });

  final int imports;
  final int operations;

  /// Le lot d'indice `failOnDelete.$1` (à partir de 0) échoue avec ce code.
  final (int, ServiceFailureCode)? failOnDelete;

  /// La liste de cette nature échoue avec ce code.
  final (MarkerKind, ServiceFailureCode)? failOnList;

  final List<String> calls = [];
  final List<DateTime> bounds = [];
  final List<List<StaleMarker>> deleted = [];

  static String id(int i) => '${i.toRadixString(16).padLeft(64, '0')}_u-gone';

  @override
  Future<List<StaleMarker>> list(
    ClubId club,
    MarkerKind kind,
    DateTime before,
  ) async {
    calls.add('list ${club.value} ${kind.name}');
    bounds.add(before);
    final fail = failOnList;
    if (fail != null && fail.$1 == kind) {
      throw ServiceFailure(fail.$2, 'liste');
    }
    final count = kind == MarkerKind.import ? imports : operations;
    final offset = kind == MarkerKind.import ? 0 : 100000;
    return [for (var i = 0; i < count; i++) StaleMarker(kind, id(offset + i))];
  }

  @override
  Future<void> delete(ClubId club, List<StaleMarker> markers) async {
    calls.add('delete ${club.value} ${markers.length}');
    final fail = failOnDelete;
    if (fail != null && fail.$1 == deleted.length) {
      throw ServiceFailure(fail.$2, 'lot');
    }
    deleted.add(markers);
  }
}

void main() {
  const club = ClubId('c1');
  late FixedClock clock;
  late InMemoryWriteLedger ledger;

  setUp(() {
    clock = FixedClock(DateTime(2026, 10, 24, 10));
    ledger = InMemoryWriteLedger(clock);
  });

  SessionScope scopeOf(Role? role) {
    final scope = SessionScope()..signIn(const UserId('u-dir'));
    if (role != null) scope.activate(club, role);
    return scope;
  }

  PurgeStaleMarkers purge(
    _Store store, {
    Role? role = Role.director,
    OperationLimits limits = const OperationLimits(),
  }) => PurgeStaleMarkers(store, ledger, clock, scopeOf(role), limits: limits);

  test('the age is 90 days and the query keeps one day of clock margin', () {
    expect(staleMarkerAge, const Duration(days: 90));
    expect(staleMarkerClockMargin, const Duration(days: 1));
  });

  for (final role in [Role.teacher, Role.guardian, Role.student, null]) {
    test(
      'a ${role?.name ?? 'club-less'} account is refused before any read',
      () async {
        final store = _Store(imports: 3);

        final result = await purge(store, role: role)();

        expect(result.status, StaleMarkerPurgeStatus.failed);
        expect(result.failure?.code, ServiceFailureCode.denied);
        expect(result.removed, 0);
        expect(store.calls, isEmpty);
        expect(await ledger.spentToday(), 0);
      },
    );
  }

  for (final role in [Role.director, Role.admin]) {
    test('a ${role.name} removes the stale imports, then operations', () async {
      final store = _Store(imports: 2, operations: 1);

      final result = await purge(store, role: role)();

      expect(result.status, StaleMarkerPurgeStatus.completed);
      expect(result.removed, 3);
      expect(store.calls, [
        'list c1 import',
        'delete c1 2',
        'list c1 operation',
        'delete c1 1',
      ]);
      expect(await ledger.spentToday(), 3);
    });
  }

  test('the bound is 91 days before now (90 days and the margin)', () async {
    final store = _Store();

    await purge(store)();

    expect(store.bounds, [
      DateTime(2026, 7, 25, 10),
      DateTime(2026, 7, 25, 10),
    ]);
  });

  test('nothing stale: no lot is sent and nothing is counted', () async {
    final store = _Store();

    final result = await purge(store)();

    expect(result.status, StaleMarkerPurgeStatus.completed);
    expect(result.removed, 0);
    expect(store.deleted, isEmpty);
    expect(await ledger.spentToday(), 0);
  });

  test('801 markers leave in lots of 400, 400 and 1', () async {
    final store = _Store(imports: 801);

    final result = await purge(store)();

    expect([for (final lot in store.deleted) lot.length], [400, 400, 1]);
    expect(result.removed, 801);
    expect(store.deleted.expand((lot) => lot).toSet(), hasLength(801));
  });

  test(
    'a lot that would pass the daily ceiling pauses until tomorrow',
    () async {
      await ledger.add(9550);
      final store = _Store(imports: 452);

      final result = await purge(store)();

      expect(result.status, StaleMarkerPurgeStatus.paused);
      expect(result.removed, 400);
      expect(await ledger.spentToday(), 9950);
    },
  );

  test('the first lot of the day is always written', () async {
    final store = _Store(imports: 900);

    final result = await purge(
      store,
      limits: const OperationLimits(dailyWrites: 300),
    )();

    expect(result.status, StaleMarkerPurgeStatus.paused);
    expect(result.removed, 400);
    expect(await ledger.spentToday(), 400);
  });

  test('a list without network interrupts, nothing removed', () async {
    final store = _Store(
      imports: 3,
      failOnList: (MarkerKind.import, ServiceFailureCode.unavailable),
    );

    final result = await purge(store)();

    expect(result.status, StaleMarkerPurgeStatus.interrupted);
    expect(result.failure?.code, ServiceFailureCode.unavailable);
    expect(result.removed, 0);
    expect(store.deleted, isEmpty);
  });

  test('a refused list fails and keeps what was already removed', () async {
    final store = _Store(
      imports: 2,
      operations: 1,
      failOnList: (MarkerKind.operation, ServiceFailureCode.denied),
    );

    final result = await purge(store)();

    expect(result.status, StaleMarkerPurgeStatus.failed);
    expect(result.failure?.code, ServiceFailureCode.denied);
    expect(result.removed, 2);
  });

  test(
    'a lot left without answer interrupts; it is counted (it may still go)',
    () async {
      final store = _Store(
        imports: 450,
        failOnDelete: (1, ServiceFailureCode.unavailable),
      );

      final result = await purge(store)();

      expect(result.status, StaleMarkerPurgeStatus.interrupted);
      expect(result.removed, 400);
      expect(await ledger.spentToday(), 450);
    },
  );

  test('a refused lot fails and is not counted', () async {
    final store = _Store(
      imports: 450,
      failOnDelete: (1, ServiceFailureCode.denied),
    );

    final result = await purge(store)();

    expect(result.status, StaleMarkerPurgeStatus.failed);
    expect(result.failure?.code, ServiceFailureCode.denied);
    expect(result.removed, 400);
    expect(await ledger.spentToday(), 400);
    expect(store.calls, isNot(contains('list c1 operation')));
  });
}
