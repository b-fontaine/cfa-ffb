import 'package:billard_cfa/features/track_progress/domain/get_week_summary.dart';
import 'package:billard_cfa/features/track_progress/domain/week_summary.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/week_summary_cubit.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGet extends Mock implements GetWeekSummary;

void main() {
  late _MockGet get;
  final summary = WeekSummary(
    from: DateTime(2026, 10, 6),
    to: DateTime(2026, 10, 12),
    passes: 12,
    validations: 2,
    sessions: 1,
  );

  setUp(() => get = _MockGet());

  blocTest<WeekSummaryCubit, WeekSummaryState>(
    'loads the week',
    setUp: () => when(() => get()).thenAnswer((_) async => Ok(summary)),
    build: () => WeekSummaryCubit(get),
    act: (cubit) => cubit.load(),
    expect: () => [
      WeekSummaryState(status: WeekStatus.ready, summary: summary),
    ],
  );

  blocTest<WeekSummaryCubit, WeekSummaryState>(
    'reports a failure',
    setUp: () => when(
      () => get(),
    ).thenAnswer((_) async => const Err<WeekSummary>(NotFound('season', 'x'))),
    build: () => WeekSummaryCubit(get),
    act: (cubit) => cubit.load(),
    expect: () => [
      const WeekSummaryState(
        status: WeekStatus.failure,
        failure: NotFound('season', 'x'),
      ),
    ],
  );

  blocTest<WeekSummaryCubit, WeekSummaryState>(
    'shows loading again on retry',
    setUp: () => when(() => get()).thenAnswer((_) async => Ok(summary)),
    build: () => WeekSummaryCubit(get),
    seed: () => const WeekSummaryState(status: WeekStatus.failure),
    act: (cubit) => cubit.load(),
    expect: () => [
      const WeekSummaryState(),
      WeekSummaryState(status: WeekStatus.ready, summary: summary),
    ],
  );
}
