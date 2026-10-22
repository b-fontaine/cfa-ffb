import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/operations/operation_plan.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:billard_cfa/shared/lib/operations/operation_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_operation_store.dart';
import '../../../../support/fixed_clock.dart';
import '../../../../support/in_memory_write_ledger.dart';

/// Une opération de test : des étapes dont le travail se **recalcule** d'après
/// un état (une liste d'éléments restants), comme les vraies.
class _Operation implements ResumableOperation {
  _Operation(this.state, {this.done = false});

  /// Les éléments restants de chaque étape (`state[i]`), supprimés un à un.
  final List<List<String>> state;
  bool done;
  final List<String> log = [];
  int planned = 0;

  @override
  OperationKind get kind => OperationKind.erasure;

  @override
  String get key => 'k' * 64;

  @override
  ClosureTerms? get terms => null;

  @override
  Future<bool> isAlreadyDone() async => done;

  @override
  late final List<OperationStage> stages = [
    for (var i = 0; i < state.length; i++) _Stage(this, i),
  ];
}

class _Stage implements OperationStage {
  _Stage(this.operation, this.index);

  final _Operation operation;
  final int index;

  @override
  Future<List<OperationLot>> remaining(int maxWrites) async {
    operation.planned++;
    final left = operation.state[index];
    return [
      for (var i = 0; i < left.length; i += maxWrites)
        () {
          final chunk = left.sublist(
            i,
            i + maxWrites > left.length ? left.length : i + maxWrites,
          );
          return OperationLot(
            writes: chunk.length,
            apply: () async {
              operation.log.add('$index:${chunk.join(',')}');
              operation.state[index].removeWhere(chunk.contains);
            },
          );
        }(),
    ];
  }
}

void main() {
  late FakeOperationStore store;
  late FixedClock clock;
  late InMemoryWriteLedger ledger;

  setUp(() {
    store = FakeOperationStore();
    clock = FixedClock(DateTime.utc(2026, 10, 12, 10));
    ledger = InMemoryWriteLedger(clock);
  });

  OperationRunner runner({int lotSize = 4, int dailyWrites = 100000}) =>
      OperationRunner(
        store,
        ledger,
        limits: OperationLimits(lotSize: lotSize, dailyWrites: dailyWrites),
      );

  Future<OperationRunResult> run(
    OperationRunner runner,
    ResumableOperation operation, {
    bool Function()? shouldStop,
    void Function(int, int)? onProgress,
  }) async => switch (await runner(
    operation,
    role: Role.director,
    shouldStop: shouldStop,
    onProgress: onProgress,
  )) {
    Ok(:final value) => value,
    Err(:final failure) => fail('refusé : $failure'),
  };

  test('runs the stages in order, one lot per chunk of three writes', () async {
    final operation = _Operation([
      ['a', 'b', 'c', 'd'],
      ['e'],
    ]);

    final result = await run(runner(), operation);

    expect(result.status, OperationRunStatus.completed);
    expect(operation.log, ['0:a,b,c', '0:d', '1:e']);
    expect(result.writes, 5);
    expect(store.marker, isNull, reason: 'le dernier lot supprime le marqueur');
  });

  test(
    'the first lot creates the marker and each lot advances it by one',
    () async {
      final operation = _Operation([
        ['a', 'b', 'c', 'd'],
        ['e'],
      ]);
      final seen = <(int, int)>[];
      final r = runner();

      final result = await r(
        operation,
        role: Role.director,
        onProgress: (done, total) {
          final marker = store.marker;
          if (marker != null) seen.add((marker.done, marker.stage));
        },
      );

      expect(result, isA<Ok<OperationRunResult>>());
      // Après chaque lot : 1 lot (étape 0), 2 lots (étape 1), 3 lots (étape 1).
      expect(seen, containsAllInOrder([(1, 0), (2, 1)]));
    },
  );

  test('a stage without work advances the marker with an empty lot', () async {
    final operation = _Operation([
      [],
      ['a'],
      [],
    ]);

    final result = await run(runner(), operation);

    expect(result.status, OperationRunStatus.completed);
    expect(operation.log, ['1:a']);
    expect(store.applied, hasLength(3));
    expect(store.marker, isNull);
  });

  test('an operation already done writes nothing', () async {
    final operation = _Operation([
      ['a'],
    ], done: true);

    final result = await run(runner(), operation);

    expect(result.status, OperationRunStatus.completed);
    expect(result.alreadyDone, isTrue);
    expect(store.applied, isEmpty);
    expect(operation.log, isEmpty);
  });

  test(
    'a connection that drops interrupts and the resumption finishes',
    () async {
      final operation = _Operation([
        ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
        ['h'],
      ]);
      store.failAfter = 2;

      final first = await run(runner(), operation);

      expect(first.status, OperationRunStatus.interrupted);
      expect(first.failure?.code, ServiceFailureCode.unavailable);
      expect(store.marker?.done, 2);
      expect(operation.log, ['0:a,b,c', '0:d,e,f']);

      store.failAfter = null;
      final second = await run(runner(), operation);

      expect(second.status, OperationRunStatus.completed);
      expect(operation.log, ['0:a,b,c', '0:d,e,f', '0:g', '1:h']);
      expect(store.marker, isNull);
    },
  );

  test('a lot applied elsewhere is a success', () async {
    final operation = _Operation([
      ['a', 'b', 'c', 'd', 'e', 'f'],
      ['g'],
    ]);
    final r = runner();
    // Le premier lot passe ; le deuxième est refusé parce qu'un autre appareil
    // a déjà appliqué ce lot : le marqueur a avancé de deux.
    var calls = 0;
    store.elsewhere = null;
    final proxy = _Elsewhere(store, () {
      calls++;
      if (calls == 2) {
        operation.state[0].removeWhere(const ['d', 'e', 'f'].contains);
        store.marker = store.marker!.advanced(nextStage: 0);
      }
    });
    final withProxy = OperationRunner(
      proxy,
      ledger,
      limits: const OperationLimits(lotSize: 4),
    );

    final result = await run(withProxy, operation);

    expect(result.status, OperationRunStatus.completed);
    // Rien n'a été fait deux fois : le travail restant a été recalculé.
    expect(operation.log, ['0:a,b,c', '1:g']);
    expect(r, isNotNull);
  });

  test(
    'a rejection with the marker unchanged is a failure, nothing is lost',
    () async {
      final operation = _Operation([
        ['a', 'b', 'c', 'd'],
      ]);
      store.failNextWith = ServiceFailureCode.denied;

      final result = await run(runner(), operation);

      expect(result.status, OperationRunStatus.failed);
      expect(result.failure?.code, ServiceFailureCode.denied);
      expect(operation.log, isEmpty);
      expect(store.marker, isNull);
    },
  );

  test('another device that finishes leaves the operation completed', () async {
    final operation = _Operation([
      ['a', 'b', 'c', 'd', 'e', 'f'],
    ]);
    var calls = 0;
    final proxy = _Elsewhere(store, () {
      calls++;
      if (calls == 2) {
        operation
          ..state[0].clear()
          ..done = true;
        store.marker = null;
      }
    });

    final result = await run(
      OperationRunner(proxy, ledger, limits: const OperationLimits(lotSize: 4)),
      operation,
    );

    expect(result.status, OperationRunStatus.completed);
    expect(operation.log, ['0:a,b,c']);
  });

  test('stopping is read before each lot, never inside one', () async {
    final operation = _Operation([
      ['a', 'b', 'c', 'd', 'e', 'f'],
    ]);
    var lots = 0;

    final result = await run(
      runner(),
      operation,
      shouldStop: () => lots++ >= 1,
    );

    expect(result.status, OperationRunStatus.cancelled);
    expect(operation.log, ['0:a,b,c']);
    expect(store.marker?.done, 1);

    final resumed = await run(runner(), operation);
    expect(resumed.status, OperationRunStatus.completed);
    expect(operation.log, ['0:a,b,c', '0:d,e,f']);
  });

  test(
    'the daily ceiling pauses before the lot that would exceed it',
    () async {
      final operation = _Operation([
        ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'],
      ]);
      final r = runner(dailyWrites: 5);

      final first = await run(r, operation);

      // Un lot de 3 écritures + marqueur = 4 : le second dépasserait 5.
      expect(first.status, OperationRunStatus.paused);
      expect(operation.log, ['0:a,b,c']);
      expect((await run(r, operation)).status, OperationRunStatus.paused);
      expect(operation.log, ['0:a,b,c'], reason: 'rien de plus le même jour');

      clock.advance(const Duration(days: 1));
      final second = await run(r, operation);

      expect(second.status, OperationRunStatus.paused);
      expect(operation.log, ['0:a,b,c', '0:d,e,f']);
      clock.advance(const Duration(days: 1));
      expect((await run(r, operation)).status, OperationRunStatus.completed);
      expect(operation.log, ['0:a,b,c', '0:d,e,f', '0:g,h,i']);
    },
  );

  // Trois lots de coût 3 (deux écritures + le marqueur) : un lot qui atteint
  // EXACTEMENT le plafond passe, celui qui le dépasse d'une écriture s'arrête.
  for (final (ceiling, lots) in [(5, 1), (6, 2), (7, 2), (8, 2), (9, 3)]) {
    test(
      'a ceiling of $ceiling lets exactly $lots lots of cost 3 through',
      () async {
        final operation = _Operation([
          ['a', 'b', 'c', 'd', 'e', 'f'],
        ]);

        final result = await run(
          runner(lotSize: 3, dailyWrites: ceiling),
          operation,
        );

        expect(operation.log, hasLength(lots));
        expect(
          result.status,
          lots == 3 ? OperationRunStatus.completed : OperationRunStatus.paused,
        );
      },
    );
  }

  test(
    'the lot that is cut by the network counts against the ceiling',
    () async {
      final operation = _Operation([
        ['a', 'b', 'c', 'd', 'e', 'f'],
      ]);
      store.failAfter = 1;
      final r = runner(dailyWrites: 100);

      await run(r, operation);
      store.failAfter = 2;
      await run(r, operation);

      expect(await ledger.spentToday(), greaterThanOrEqualTo(8));
    },
  );

  test(
    'progress reports the lots done on the lots planned, start included',
    () async {
      final operation = _Operation([
        ['a', 'b', 'c', 'd'],
        ['e'],
      ]);
      final progress = <(int, int)>[];

      await run(
        runner(),
        operation,
        onProgress: (d, t) => progress.add((d, t)),
      );

      expect(progress.first, (0, 3));
      expect(progress.last.$1, progress.last.$2);
      expect(
        progress.map((p) => p.$1),
        orderedEquals([...progress.map((p) => p.$1)]..sort()),
      );
    },
  );

  test(
    'an unreadable server leaves the run interrupted before any write',
    () async {
      final operation = _Operation([
        ['a'],
      ]);
      final proxy = _Elsewhere(store, () {}, failRead: true);

      final result = await OperationRunner(proxy, ledger)(
        operation,
        role: Role.director,
      );

      expect(result, isA<Err<OperationRunResult>>());
      expect(operation.log, isEmpty);
    },
  );
}

/// Un magasin qui appelle [hook] avant chaque lot (un autre appareil qui agit).
class _Elsewhere implements OperationStore {
  _Elsewhere(this.inner, this.hook, {this.failRead = false});

  final FakeOperationStore inner;
  final void Function() hook;
  final bool failRead;

  @override
  Future<List<OperationMarker>> ownMarkers() => inner.ownMarkers();

  @override
  Future<OperationMarker?> readMarker(String key) async {
    if (failRead) {
      throw const ServiceFailure(ServiceFailureCode.unavailable, 'hors ligne');
    }
    return inner.marker;
  }

  @override
  Future<void> commit(OperationLotCommit commit) async {
    hook();
    await inner.commit(commit);
  }
}
