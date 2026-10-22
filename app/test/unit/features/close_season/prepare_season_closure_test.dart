import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/close_season/domain/closure_proposal.dart';
import 'package:billard_cfa/features/close_season/domain/get_closable_season.dart';
import 'package:billard_cfa/features/close_season/domain/prepare_season_closure.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late PrepareSeasonClosure prepare;

  setUp(() async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['a', 'b']);
    prepare = PrepareSeasonClosure(
      world.seasons,
      world.groups,
      world.students,
      world.sessions,
      world.attempts,
      world.plannedSessions,
    );
  });

  group('PrepareSeasonClosure', () {
    test('proposes a choice for each student, from the rule', () async {
      await world.session(dayOfMonth: 3, present: {'a'});

      final plan = ok(
        await prepare(seasonId: const SeasonId('season'), today: day(12)),
      );

      expect(
        {for (final p in plan.proposals) p.firstName: p.choice},
        {'a': ClosureChoice.keep, 'b': ClosureChoice.erase},
      );
    });

    test('proposes to erase a student who never had a group', () async {
      await world.students.create(
        (await world.students.byId(const StudentId('a')))!
            .copyWith(id: const StudentId('loose'), firstName: 'loose'),
      );

      final plan = ok(
        await prepare(seasonId: const SeasonId('season'), today: day(12)),
      );

      final loose = plan.proposals.firstWhere((p) => p.firstName == 'loose');
      expect(loose.choice, ClosureChoice.erase);
    });

    test('previews the archive figures without storing anything', () async {
      await world.students.create(
        (await world.students.byId(const StudentId('a')))!
            .copyWith(id: const StudentId('c'), firstName: 'c'),
      );
      final group = (await world.groups.byId(const GroupId('g1')))!;
      await world.groups.save(
        group.admit(
          studentId: const StudentId('c'),
          studentAudience: Audience.children,
          from: day(1),
        ),
      );
      await world.session(dayOfMonth: 3, present: {'a', 'b'});
      await world.session(id: 'x2', dayOfMonth: 4, present: {'a', 'c'});

      final plan = ok(
        await prepare(seasonId: const SeasonId('season'), today: day(12)),
      );

      expect(plan.sessionCount, 2);
      expect(plan.presenceCount, 4);
      expect(await world.seasonArchives.all(), isEmpty);
      expect(
        (await world.seasons.byId(const SeasonId('season')))!.isClosed,
        isFalse,
      );
    });

    test('flags an early closure and proposes today as closing day', () async {
      final plan = ok(
        await prepare(seasonId: const SeasonId('season'), today: day(12)),
      );

      expect(plan.closedOn, day(12));
      expect(plan.early, isTrue);
    });

    test('is not early once the season is over', () async {
      final plan = ok(
        await prepare(
          seasonId: const SeasonId('season'),
          today: DateTime(2026, 11, 20),
        ),
      );

      expect(plan.closedOn, DateTime(2026, 11, 20));
      expect(plan.early, isFalse);
    });

    test(
      'never proposes a closing day before the start of the season',
      () async {
        final plan = ok(
          await prepare(
            seasonId: const SeasonId('season'),
            today: DateTime(2026, 9),
          ),
        );

        expect(plan.closedOn, day(2));
      },
    );

    test('counts the planned sessions that closing would drop', () async {
      for (final (id, date) in [('p1', 5), ('p2', 20), ('p3', 25)]) {
        await world.plannedSessions.add(
          Session(
            id: id,
            title: id,
            date: day(date),
            audience: Audience.children,
            groupId: const GroupId('g1'),
          ),
        );
      }

      final plan = ok(
        await prepare(seasonId: const SeasonId('season'), today: day(12)),
      );

      expect(plan.plannedToDrop, 2);
    });

    test('refuses an unknown or closed season', () async {
      expect(
        err(await prepare(seasonId: const SeasonId('ghost'), today: day(12))),
        isA<NotFound>(),
      );
      await world.seasons.save(
        (await world.seasons.byId(const SeasonId('season')))!
            .copyWith(closedOn: day(10)),
      );
      expect(
        codeOf(
          await prepare(seasonId: const SeasonId('season'), today: day(12)),
        ),
        InvariantCode.seasonAlreadyClosed,
      );
    });
  });

  group('GetClosableSeason', () {
    late GetClosableSeason find;

    setUp(() => find = GetClosableSeason(world.seasons));

    Future<void> addSeason(
      String id,
      DateTime start,
      DateTime end, {
      DateTime? closedOn,
    }) => world.seasons.save(
      Season(
        id: SeasonId(id),
        label: id,
        startDate: start,
        endDate: end,
        closedOn: closedOn,
      ),
    );

    test('finds nothing while the season is running', () async {
      expect(await find(today: day(12)), isNull);
    });

    test('finds a season whose end is past and that is not closed', () async {
      expect(
        (await find(today: DateTime(2026, 11)))!.id,
        const SeasonId('season'),
      );
    });

    test('is still running on its last day', () async {
      expect(await find(today: day(31)), isNull);
    });

    test(
      'ignores a closed season and takes the oldest of the others',
      () async {
        await addSeason(
          'old',
          DateTime(2025, 9),
          DateTime(2026, 6, 30),
          closedOn: DateTime(2026, 6, 30),
        );
        await addSeason('older', DateTime(2024, 9), DateTime(2025, 6, 30));

        expect(
          (await find(today: DateTime(2026, 11)))!.id,
          const SeasonId('older'),
        );
      },
    );
  });
}
