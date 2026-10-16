import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/features/track_seasons/domain/list_season_archives.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late ListSeasonArchives list;

  Future<void> addSeason(String id, int year, {bool closed = true}) =>
      world.seasons.save(
        Season(
          id: SeasonId(id),
          label: '$year-${year + 1}',
          startDate: DateTime(year, 9),
          endDate: DateTime(year + 1, 6, 30),
          closedOn: closed ? DateTime(year + 1, 6, 30) : null,
        ),
      );

  setUp(() {
    world = DomainWorld();
    list = ListSeasonArchives(
      world.seasons,
      world.seasonArchives,
      world.catalogueRepository,
    );
  });

  test('lists the closed seasons, the most recent first', () async {
    await addSeason('a', 2024);
    await addSeason('b', 2025);
    await addSeason('open', 2026, closed: false);

    final seasons = ok(await list());

    expect(seasons.map((s) => s.season.label), ['2025-2026', '2024-2025']);
  });

  test(
    'joins the archive with the technique titles of the catalogue',
    () async {
      await addSeason('a', 2025);
      await world.seasonArchives.save(
        SeasonArchive(
          seasonId: const SeasonId('a'),
          audiences: [
            AudienceArchive(
              audience: Audience.children,
              sessionCount: 4,
              presenceCount: 12,
              possiblePresenceCount: 16,
              studentCount: 5,
              attemptCount: 20,
            ),
          ],
          exercises: [
            ExerciseArchive(
              audience: Audience.children,
              exercise: ref('a', 2),
              studentCount: 3,
              attemptCount: 6,
              potted: 9,
              total: 18,
            ),
            ExerciseArchive(
              audience: Audience.children,
              exercise: ref('inconnu', 1),
              studentCount: 3,
              attemptCount: 3,
              potted: 3,
              total: 9,
            ),
          ],
        ),
      );

      final closed = ok(await list()).single;

      expect(closed.audiences.single.presenceCount, 12);
      expect(closed.exercises.first.blockTitle, 'Bloc a');
      expect(closed.exercises.first.exerciseNumber, 2);
      expect(closed.exercises.first.potted, 9);
      expect(closed.exercises.last.blockTitle, 'inconnu');
    },
  );

  test('lists a closed season without archive with no figures', () async {
    await addSeason('a', 2025);

    final closed = ok(await list()).single;

    expect(closed.audiences, isEmpty);
    expect(closed.exercises, isEmpty);
  });

  test('has nothing to list while no season is closed', () async {
    await addSeason('open', 2026, closed: false);

    expect(ok(await list()), isEmpty);
  });
}
