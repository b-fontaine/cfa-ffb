import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/domain/get_upcoming_sessions.dart';
import 'package:billard_cfa/features/plan_session/domain/planned_session_summary.dart';
import 'package:billard_cfa/features/plan_session/domain/upcoming_sessions.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/upcoming_sessions_cubit.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGet extends Mock implements GetUpcomingSessions;

void main() {
  late _MockGet get;
  final upcoming = UpcomingSessions(
    next: PlannedSessionSummary(
      session: Session(
        id: 'p1',
        title: 'Séance',
        date: DateTime(2026, 10, 14),
        audience: Audience.children,
      ),
    ),
  );

  setUp(() => get = _MockGet());

  test('starts loading', () {
    expect(UpcomingSessionsCubit(get).state.status, UpcomingStatus.loading);
  });

  blocTest<UpcomingSessionsCubit, UpcomingSessionsState>(
    'loads the upcoming sessions',
    setUp: () => when(() => get()).thenAnswer((_) async => Ok(upcoming)),
    build: () => UpcomingSessionsCubit(get),
    act: (cubit) => cubit.load(),
    expect: () => [
      UpcomingSessionsState(status: UpcomingStatus.ready, upcoming: upcoming),
    ],
  );

  blocTest<UpcomingSessionsCubit, UpcomingSessionsState>(
    'reports a failure and can retry',
    setUp: () {
      var calls = 0;
      when(() => get()).thenAnswer(
        (_) async => calls++ == 0
            ? const Err<UpcomingSessions>(NotFound('season', 'x'))
            : Ok(upcoming),
      );
    },
    build: () => UpcomingSessionsCubit(get),
    act: (cubit) async {
      await cubit.load();
      await cubit.load();
    },
    expect: () => [
      const UpcomingSessionsState(
        status: UpcomingStatus.failure,
        failure: NotFound('season', 'x'),
      ),
      const UpcomingSessionsState(),
      UpcomingSessionsState(status: UpcomingStatus.ready, upcoming: upcoming),
    ],
  );
}
