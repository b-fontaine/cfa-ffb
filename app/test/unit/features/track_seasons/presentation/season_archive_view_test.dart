import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/features/track_seasons/domain/closed_season.dart';
import 'package:billard_cfa/features/track_seasons/presentation/bloc/season_archives_cubit.dart';
import 'package:billard_cfa/features/track_seasons/presentation/ui/season_archive_view.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../shared/ui/pump_ui.dart';

class _MockCubit extends MockCubit<SeasonArchivesState>
    implements SeasonArchivesCubit;

void main() {
  late _MockCubit cubit;

  setUp(() => cubit = _MockCubit());

  Future<void> pump(WidgetTester tester, SeasonArchivesState state) async {
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.load()).thenAnswer((_) async {});
    await pumpUi(
      tester,
      BlocProvider<SeasonArchivesCubit>.value(
        value: cubit,
        child: const SingleChildScrollView(child: SeasonArchiveView()),
      ),
    );
  }

  final season = Season(
    id: const SeasonId('s'),
    label: '2025-2026',
    startDate: DateTime(2025, 9),
    endDate: DateTime(2026, 6, 30),
    closedOn: DateTime(2026, 6, 30),
  );

  testWidgets('shows a progress indicator while loading', (tester) async {
    await pump(tester, const SeasonArchivesState());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('offers a retry after a failure', (tester) async {
    await pump(
      tester,
      const SeasonArchivesState(
        status: SeasonArchivesStatus.failure,
        failure: NotFound('s', 'x'),
      ),
    );

    expect(find.text('Item not found.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    verify(() => cubit.load()).called(1);
  });

  testWidgets('says why nothing is listed yet', (tester) async {
    await pump(
      tester,
      const SeasonArchivesState(status: SeasonArchivesStatus.ready),
    );

    expect(
      find.text(
        'No closed season yet. When you close a season, its figures will '
        'stay here, without any name.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the figures of both audiences and the exercise table', (
    tester,
  ) async {
    await pump(
      tester,
      SeasonArchivesState(
        status: SeasonArchivesStatus.ready,
        seasons: [
          ClosedSeason(
            season: season,
            audiences: [
              AudienceArchive(
                audience: Audience.children,
                sessionCount: 1,
                presenceCount: 3,
                possiblePresenceCount: 4,
                studentCount: 3,
                attemptCount: 0,
              ),
              AudienceArchive(
                audience: Audience.adults,
                sessionCount: 2,
                presenceCount: 4,
                possiblePresenceCount: 4,
                studentCount: 3,
                attemptCount: 5,
              ),
            ],
            exercises: const [
              ExerciseLine(
                audience: Audience.children,
                blockTitle: 'Posture',
                exerciseNumber: 1,
                studentCount: 3,
                attemptCount: 3,
                potted: 9,
                total: 12,
              ),
            ],
          ),
        ],
      ),
    );

    expect(find.text('2025-2026'), findsOneWidget);
    expect(find.text('1 session'), findsOneWidget);
    expect(find.text('2 sessions'), findsOneWidget);
    expect(find.text('3 attendances out of 4 possible'), findsOneWidget);
    expect(find.text('No pass'), findsOneWidget);
    expect(find.text('5 passes'), findsOneWidget);
    expect(find.text('Posture · 1'), findsOneWidget);
    expect(
      find.text(
        'Exercises practised by fewer than 3 students are not detailed.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('says the figures of a small audience are not kept', (
    tester,
  ) async {
    await pump(
      tester,
      SeasonArchivesState(
        status: SeasonArchivesStatus.ready,
        seasons: [
          ClosedSeason(
            season: season,
            audiences: [
              AudienceArchive(
                audience: Audience.adults,
                sessionCount: 2,
                presenceCount: 0,
                possiblePresenceCount: 0,
                studentCount: 2,
                attemptCount: 0,
              ),
            ],
            exercises: const [],
          ),
        ],
      ),
    );

    expect(find.text('2 sessions'), findsOneWidget);
    expect(
      find.text('Fewer than 3 students: attendances and passes are not kept.'),
      findsOneWidget,
    );
    expect(find.textContaining('possible'), findsNothing);
  });

  testWidgets('says a closed season had no session', (tester) async {
    await pump(
      tester,
      SeasonArchivesState(
        status: SeasonArchivesStatus.ready,
        seasons: [
          ClosedSeason(
            season: season,
            audiences: const [],
            exercises: const [],
          ),
        ],
      ),
    );

    expect(find.text('No session this season.'), findsOneWidget);
    expect(find.text('Exercises practised'), findsNothing);
  });
}
