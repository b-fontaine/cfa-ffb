import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_progress_keeper.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late FixedClock clock;
  late RunProgressKeeper keeper;
  final key = RunProgressKey(sheetId: SheetId('demi-bille-1'));

  setUp(() async {
    world = DomainWorld();
    clock = FixedClock(DateTime.utc(2026, 10, 16, 9));
    keeper = RunProgressKeeper(
      world.runProgress,
      world.sessions,
      world.groups,
      clock,
    );
    await world.seedClub(studentNames: ['s1', 's2', 's3']);
  });

  group('save and saved', () {
    test('stamps the progress with the clock and reads it back', () async {
      await keeper.save(
        key: key,
        step: 3,
        counts: {'ini': 2},
        checked: {
          'grille': {1},
        },
        scoreA: 4,
        scoreB: 5,
        timerSeconds: 40,
        recordId: const SessionId('x1'),
      );

      final saved = (await keeper.saved(key))!;

      expect(saved.updatedAt, clock.now());
      expect(saved.step, 3);
      expect(saved.counts, {'ini': 2});
      expect(saved.checked, {
        'grille': {1},
      });
      expect(saved.scoreA, 4);
      expect(saved.scoreB, 5);
      expect(saved.timerSeconds, 40);
      expect(saved.recordId, const SessionId('x1'));
    });

    test('forget erases the progress of that key only', () async {
      await keeper.save(key: key, step: 1);
      final other = RunProgressKey(sheetId: SheetId('posture-1'));
      await keeper.save(key: other, step: 1);

      await keeper.forget(key);

      expect(await keeper.saved(key), isNull);
      expect(await keeper.saved(other), isNotNull);
    });
  });

  group('recordLink', () {
    test('reads group and date from the record and the absent students from '
        'the roster', () async {
      await world.session(dayOfMonth: 5, present: {'s1', 's3'});

      final link = (await keeper.recordLink(const SessionId('x1')))!;

      expect(link.recordId, const SessionId('x1'));
      expect(link.group, const GroupId('g1'));
      expect(link.date, day(5));
      expect(link.absent, {const StudentId('s2')});
    });

    test('has no absent student when everyone was present', () async {
      await world.session(present: {'s1', 's2', 's3'});

      expect((await keeper.recordLink(const SessionId('x1')))!.absent, isEmpty);
    });

    test('does not count a student who joined the group after the record '
        'as absent', () async {
      await world.seedClub(studentNames: ['s1', 's2']);
      await world.session(present: {'s1', 's2'});
      final group = (await world.groups.byId(const GroupId('g1')))!;
      await world.groups.save(
        group.admit(
          studentId: const StudentId('s3'),
          studentAudience: group.audience,
          from: day(10),
        ),
      );

      expect((await keeper.recordLink(const SessionId('x1')))!.absent, isEmpty);
    });

    test('is null for a record that does not exist', () async {
      expect(await keeper.recordLink(const SessionId('ghost')), isNull);
    });

    test('is null for a record that was deleted', () async {
      await world.session();
      await world.sessions.delete(const SessionId('x1'));

      expect(await keeper.recordLink(const SessionId('x1')), isNull);
    });

    test(
      'keeps the record but no absent student when its group is gone',
      () async {
        await world.session();
        await world.groups.delete(const GroupId('g1'));

        final link = (await keeper.recordLink(const SessionId('x1')))!;

        expect(link.group, const GroupId('g1'));
        expect(link.absent, isEmpty);
      },
    );
  });

  group('purgeStale', () {
    Future<void> saveAt(String sheet, DateTime at) async {
      clock = FixedClock(at);
      keeper = RunProgressKeeper(
        world.runProgress,
        world.sessions,
        world.groups,
        clock,
      );
      await keeper.save(key: RunProgressKey(sheetId: SheetId(sheet)), step: 1);
    }

    test(
      'erases a progress older than seven days and keeps the others',
      () async {
        final now = DateTime.utc(2026, 10, 16, 9);
        await saveAt(
          'vieille-1',
          now.subtract(const Duration(days: 7, seconds: 1)),
        );
        await saveAt('limite-1', now.subtract(const Duration(days: 7)));
        await saveAt('recente-1', now.subtract(const Duration(days: 1)));
        clock = FixedClock(now);
        keeper = RunProgressKeeper(
          world.runProgress,
          world.sessions,
          world.groups,
          clock,
        );

        final purged = await keeper.purgeStale();

        expect(purged, 1);
        expect([
          for (final p in await world.runProgress.all()) p.key.sheetId.value,
        ], unorderedEquals(['limite-1', 'recente-1']));
      },
    );
  });

  test('stale delay is seven days', () {
    expect(RunProgressKeeper.staleAfter, const Duration(days: 7));
  });
}
