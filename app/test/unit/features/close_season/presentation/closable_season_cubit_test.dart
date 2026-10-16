import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/features/close_season/domain/get_closable_season.dart';
import 'package:billard_cfa/features/close_season/presentation/bloc/closable_season_cubit.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixed_clock.dart';

class _MockFind extends Mock implements GetClosableSeason;

void main() {
  final season = Season(
    id: const SeasonId('s'),
    label: '2025-2026',
    startDate: DateTime(2025, 9),
    endDate: DateTime(2026, 6, 30),
  );

  blocTest<ClosableSeasonCubit, Season?>(
    'proposes the season whose end is past',
    build: () {
      final find = _MockFind();
      when(() => find(today: DateTime(2026, 10, 12)))
          .thenAnswer((_) async => season);
      return ClosableSeasonCubit(find, FixedClock(DateTime(2026, 10, 12, 9)));
    },
    act: (cubit) => cubit.load(),
    expect: () => [season],
  );

  blocTest<ClosableSeasonCubit, Season?>(
    'proposes nothing while no season is over',
    build: () {
      final find = _MockFind();
      when(() => find(today: DateTime(2026, 10, 12)))
          .thenAnswer((_) async => null);
      return ClosableSeasonCubit(find, FixedClock(DateTime(2026, 10, 12, 9)));
    },
    act: (cubit) => cubit.load(),
    expect: () => <Season?>[null],
  );
}
