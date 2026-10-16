import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

SeasonArchive _archive(
  String season, {
  int sessions = 2,
  List<ExerciseArchive>? exercises,
}) => SeasonArchive(
  seasonId: SeasonId(season),
  audiences: [
    AudienceArchive(
      audience: Audience.children,
      sessionCount: sessions,
      presenceCount: 5,
      possiblePresenceCount: 6,
      studentCount: 3,
      attemptCount: 4,
    ),
    AudienceArchive(
      audience: Audience.adults,
      sessionCount: 1,
      presenceCount: 2,
      possiblePresenceCount: 2,
      studentCount: 3,
      attemptCount: 0,
    ),
  ],
  exercises:
      exercises ??
      [
        ExerciseArchive(
          audience: Audience.children,
          exercise: ref('a', 1),
          studentCount: 3,
          attemptCount: 4,
          potted: 6,
          total: 20,
        ),
        ExerciseArchive(
          audience: Audience.children,
          exercise: ref('a', 2),
          studentCount: 4,
          attemptCount: 5,
          potted: 7,
          total: 25,
        ),
      ],
);

/// Suite unique du port [SeasonArchiveRepository], exécutée contre chaque
/// implémentation.
void seasonArchiveContract(
  String label,
  Future<({SeasonArchiveRepository repository, Future<void> Function() close})>
  Function()
  open,
) {
  group('$label : contrat des archives de saison', () {
    late SeasonArchiveRepository repository;
    late Future<void> Function() close;

    setUp(() async {
      final opened = await open();
      repository = opened.repository;
      close = opened.close;
    });
    tearDown(() => close());

    test('stores and reads back an archive, line for line', () async {
      await repository.save(_archive('s1'));

      final read = await repository.bySeason(const SeasonId('s1'));

      expect(read, _archive('s1'));
      expect(read!.audienceOf(Audience.adults)?.studentCount, 3);
      expect(read.exercises.map((e) => e.exercise), [ref('a', 1), ref('a', 2)]);
    });

    test('returns null for a season without archive', () async {
      expect(await repository.bySeason(const SeasonId('absent')), isNull);
    });

    test('save replaces the whole archive of the season', () async {
      await repository.save(_archive('s1'));
      await repository.save(_archive('s1', sessions: 9, exercises: const []));

      final read = (await repository.bySeason(const SeasonId('s1')))!;

      expect(read.audienceOf(Audience.children)?.sessionCount, 9);
      expect(read.exercises, isEmpty);
      expect(await repository.all(), hasLength(1));
    });

    test(
      'keeps the archives of the other seasons apart, sorted by season',
      () async {
        await repository.save(_archive('s1'));
        await repository.save(_archive('s2', sessions: 7));

        expect((await repository.all()).map((a) => a.seasonId.value), [
          's1',
          's2',
        ]);
        expect(
          (await repository.bySeason(const SeasonId('s1')))!
              .audienceOf(Audience.children)!
              .sessionCount,
          2,
        );
      },
    );

    test('delete removes only the archive of the season', () async {
      await repository.save(_archive('s1'));
      await repository.save(_archive('s2'));

      await repository.delete(const SeasonId('s1'));
      await repository.delete(const SeasonId('absent'));

      expect((await repository.all()).map((a) => a.seasonId.value), ['s2']);
    });

    test('an archive without any block leaves nothing behind', () async {
      await repository.save(_archive('empty'));
      await repository.save(
        SeasonArchive(
          seasonId: const SeasonId('empty'),
          audiences: const [],
          exercises: const [],
        ),
      );

      expect(await repository.bySeason(const SeasonId('empty')), isNull);
      expect(await repository.all(), isEmpty);
    });
  });
}
