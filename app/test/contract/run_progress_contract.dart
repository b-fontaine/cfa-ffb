import 'package:billard_cfa/entities/run_progress/domain/run_progress.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_links.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

RunProgressKey runKey(
  String sheet, {
  Audience? audience = Audience.children,
  String? session,
  String? group,
}) => RunProgressKey(
  sheetId: SheetId(sheet),
  audience: audience,
  sessionId: session,
  groupId: group == null ? null : GroupId(group),
);

DateTime _at(int minute) => DateTime.utc(2026, 10, 16, 9, minute);

RunProgress runProgress(
  RunProgressKey key, {
  int minute = 0,
  int step = 2,
  String? record,
}) => RunProgress(
  key: key,
  updatedAt: _at(minute),
  step: step,
  counts: {'ini': 3},
  checked: {
    'grille': {0, 2},
  },
  scoreA: 4,
  scoreB: 5,
  timerSeconds: 42,
  recordId: record == null ? null : SessionId(record),
  tags: {SessionTag.tooLong, SessionTag.toRedo},
);

/// Suite unique du port [RunProgressRepository], exécutée contre chaque
/// implémentation (même démarche que `acknowledgementContract`).
void runProgressContract(
  String label,
  Future<({RunProgressRepository repository, Future<void> Function() close})>
  Function()
  open,
) {
  group('$label : contrat des séances guidées en cours', () {
    late RunProgressRepository repository;
    late Future<void> Function() close;

    setUp(() async {
      final opened = await open();
      repository = opened.repository;
      close = opened.close;
    });
    tearDown(() => close());

    test('reads back everything it stored', () async {
      final key = runKey('demi-bille-1', session: 'p1', group: 'g1');
      final stored = runProgress(key, record: 'x1');

      await repository.save(stored);
      final read = await repository.byKey(key);

      expect(read, stored);
      expect(read!.counts, {'ini': 3});
      expect(read.checked, {
        'grille': {0, 2},
      });
      expect(read.recordId, const SessionId('x1'));
      expect(read.tags, {SessionTag.tooLong, SessionTag.toRedo});
      expect(read.updatedAt, _at(0));
    });

    test('keeps a progress without optional parts as it is', () async {
      final key = runKey('posture-1', audience: null);
      final stored = RunProgress(key: key, updatedAt: _at(1), step: 1);

      await repository.save(stored);

      expect(await repository.byKey(key), stored);
    });

    test('returns null for an unknown key', () async {
      expect(await repository.byKey(runKey('posture-1')), isNull);
    });

    test('save replaces the progress of the same key', () async {
      final key = runKey('demi-bille-1');

      await repository.save(runProgress(key));
      await repository.save(runProgress(key, minute: 5, step: 6));

      final all = await repository.all();
      expect(all, hasLength(1));
      expect(all.single.step, 6);
      expect(all.single.updatedAt, _at(5));
    });

    test('tells apart keys that differ only by one optional part', () async {
      await repository.save(runProgress(runKey('demi-bille-1')));
      await repository.save(
        runProgress(runKey('demi-bille-1', audience: null)),
      );
      await repository.save(runProgress(runKey('demi-bille-1', session: 'p1')));
      await repository.save(runProgress(runKey('demi-bille-1', group: 'g1')));

      expect(await repository.all(), hasLength(4));
    });

    test('all lists the most recently modified first', () async {
      await repository.save(runProgress(runKey('a-1'), minute: 3));
      await repository.save(runProgress(runKey('b-1'), minute: 9));
      await repository.save(runProgress(runKey('c-1'), minute: 6));

      final all = await repository.all();

      expect(all.map((p) => p.key.sheetId.value), ['b-1', 'c-1', 'a-1']);
    });

    test(
      'delete removes that progress only and ignores an unknown key',
      () async {
        await repository.save(runProgress(runKey('a-1')));
        await repository.save(runProgress(runKey('b-1')));

        await repository.delete(runKey('a-1'));
        await repository.delete(runKey('absent-1'));

        expect((await repository.all()).map((p) => p.key.sheetId.value), [
          'b-1',
        ]);
        expect(await repository.byKey(runKey('a-1')), isNull);
      },
    );

    test('eraseLinked erases by group and by record, nothing else', () async {
      await repository.save(runProgress(runKey('a-1', group: 'g1')));
      await repository.save(
        runProgress(runKey('b-1'), record: 'x1', minute: 1),
      );
      await repository.save(runProgress(runKey('c-1', group: 'g2'), minute: 2));
      await repository.save(
        runProgress(runKey('d-1'), record: 'x2', minute: 3),
      );
      await repository.save(runProgress(runKey('e-1'), minute: 4));

      await repository.eraseLinked(
        groups: {const GroupId('g1')},
        records: {const SessionId('x1')},
      );

      expect((await repository.all()).map((p) => p.key.sheetId.value), [
        'e-1',
        'd-1',
        'c-1',
      ]);
    });

    test('eraseLinked erases by planned session too', () async {
      await repository.save(runProgress(runKey('a-1', session: 'p1')));
      await repository.save(
        runProgress(runKey('b-1', session: 'p2'), minute: 1),
      );
      await repository.save(runProgress(runKey('c-1'), minute: 2));

      await repository.eraseLinked(plannedSessions: {'p1'});

      expect((await repository.all()).map((p) => p.key.sheetId.value), [
        'c-1',
        'b-1',
      ]);
    });

    test(
      'eraseLinked erases a progress linked by group and record once',
      () async {
        await repository.save(
          runProgress(runKey('a-1', group: 'g1'), record: 'x1'),
        );

        await repository.eraseLinked(
          groups: {const GroupId('g1')},
          records: {const SessionId('x1')},
        );

        expect(await repository.all(), isEmpty);
      },
    );

    test('eraseLinked publishes its links once the rows are gone', () async {
      await repository.save(runProgress(runKey('a-1', group: 'g1')));
      final published = <RunProgressLinks>[];
      final rowsWhenPublished = <int>[];
      final subscription = repository.erased.listen((links) async {
        published.add(links);
        rowsWhenPublished.add((await repository.all()).length);
      });

      await repository.eraseLinked(
        groups: {const GroupId('g1')},
        records: {const SessionId('x1')},
        plannedSessions: {'p1'},
      );
      await pumpEventQueue();
      await subscription.cancel();

      expect(published, hasLength(1));
      expect(published.single.groups, {const GroupId('g1')});
      expect(published.single.records, {const SessionId('x1')});
      expect(published.single.plannedSessions, {'p1'});
      expect(rowsWhenPublished, [0]);
    });

    test('eraseLinked with nothing to erase publishes nothing', () async {
      final published = <RunProgressLinks>[];
      final subscription = repository.erased.listen(published.add);

      await repository.eraseLinked();
      await pumpEventQueue();
      await subscription.cancel();

      expect(published, isEmpty);
    });

    test('eraseLinked with nothing to erase changes nothing', () async {
      await repository.save(runProgress(runKey('a-1', group: 'g1')));
      await repository.save(runProgress(runKey('b-1'), record: 'x1'));

      await repository.eraseLinked();

      expect(await repository.all(), hasLength(2));
    });

    test(
      'purgeOlderThan erases strictly older progress and counts it',
      () async {
        await repository.save(runProgress(runKey('a-1'), minute: 1));
        await repository.save(runProgress(runKey('b-1'), minute: 2));
        await repository.save(runProgress(runKey('c-1'), minute: 3));

        final purged = await repository.purgeOlderThan(_at(2));

        expect(purged, 1);
        expect((await repository.all()).map((p) => p.key.sheetId.value), [
          'c-1',
          'b-1',
        ]);
      },
    );

    test('purgeOlderThan with nothing old returns zero', () async {
      await repository.save(runProgress(runKey('a-1'), minute: 5));

      expect(await repository.purgeOlderThan(_at(1)), 0);
      expect(await repository.all(), hasLength(1));
    });
  });
}
