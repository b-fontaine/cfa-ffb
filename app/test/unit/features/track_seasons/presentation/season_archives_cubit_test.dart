import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/features/track_seasons/domain/closed_season.dart';
import 'package:billard_cfa/features/track_seasons/domain/list_season_archives.dart';
import 'package:billard_cfa/features/track_seasons/presentation/bloc/season_archives_cubit.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockList extends Mock implements ListSeasonArchives;

void main() {
  final closed = ClosedSeason(
    season: Season(
      id: const SeasonId('s'),
      label: '2025-2026',
      startDate: DateTime(2025, 9),
      endDate: DateTime(2026, 6, 30),
      closedOn: DateTime(2026, 6, 30),
    ),
    audiences: const [],
    exercises: const [],
  );

  blocTest<SeasonArchivesCubit, SeasonArchivesState>(
    'loads the closed seasons',
    build: () {
      final list = _MockList();
      when(list.call).thenAnswer((_) async => Ok([closed]));
      return SeasonArchivesCubit(list);
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      const SeasonArchivesState(),
      SeasonArchivesState(
        status: SeasonArchivesStatus.ready,
        seasons: [closed],
      ),
    ],
  );

  blocTest<SeasonArchivesCubit, SeasonArchivesState>(
    'reports a failure',
    build: () {
      final list = _MockList();
      when(list.call).thenAnswer((_) async => const Err(NotFound('s', 'x')));
      return SeasonArchivesCubit(list);
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      const SeasonArchivesState(),
      const SeasonArchivesState(
        status: SeasonArchivesStatus.failure,
        failure: NotFound('s', 'x'),
      ),
    ],
  );
}
