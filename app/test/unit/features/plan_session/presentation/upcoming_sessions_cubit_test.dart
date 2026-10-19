import 'dart:async';

import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/domain/get_upcoming_sessions.dart';
import 'package:billard_cfa/features/plan_session/domain/planned_session_summary.dart';
import 'package:billard_cfa/features/plan_session/domain/upcoming_sessions.dart';
import 'package:billard_cfa/features/plan_session/domain/watch_upcoming_sessions.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/upcoming_sessions_cubit.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/stream_log.dart';

class _MockGet extends Mock implements GetUpcomingSessions;

class _MockWatch extends Mock implements WatchUpcomingSessions;

void main() {
  late _MockGet get;
  late _MockWatch watch;
  late StreamController<void> changes;
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

  setUp(() {
    get = _MockGet();
    watch = _MockWatch();
    changes = StreamController<void>.broadcast();
    when(() => watch()).thenAnswer((_) => changes.stream);
  });

  tearDown(() => changes.close());

  test('starts loading', () {
    expect(
      UpcomingSessionsCubit(get, watch).state.status,
      UpcomingStatus.loading,
    );
  });

  blocTest<UpcomingSessionsCubit, UpcomingSessionsState>(
    'loads the upcoming sessions',
    setUp: () => when(() => get()).thenAnswer((_) async => Ok(upcoming)),
    build: () => UpcomingSessionsCubit(get, watch),
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
    build: () => UpcomingSessionsCubit(get, watch),
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

  group('live updates', () {
    final later = UpcomingSessions(
      next: PlannedSessionSummary(
        session: Session(
          id: 'p2',
          title: 'Autre séance',
          date: DateTime(2026, 10, 15),
          audience: Audience.children,
        ),
      ),
    );

    test('watches once, however many times it loads', () async {
      when(() => get()).thenAnswer((_) async => Ok(upcoming));
      final cubit = UpcomingSessionsCubit(get, watch);
      await cubit.load();
      await cubit.load();

      verify(() => watch()).called(1);
      await cubit.close();
    });

    test('reloads in place, without the loading state, on a change', () async {
      var calls = 0;
      when(() => get())
          .thenAnswer((_) async => Ok(calls++ == 0 ? upcoming : later));
      final cubit = UpcomingSessionsCubit(get, watch);
      final log = StreamLog(cubit.stream);
      await cubit.load();

      changes.add(null);
      await log.settle();

      expect(
        [for (final s in log.values) s.status],
        [UpcomingStatus.ready, UpcomingStatus.ready],
      );
      expect(log.last.upcoming, later);
      await log.cancel();
      await cubit.close();
    });

    test('a retry after a failure reopens the watch', () async {
      var calls = 0;
      when(() => get()).thenAnswer(
        (_) async => calls++ == 0
            ? const Err<UpcomingSessions>(
                ServiceFailure(ServiceFailureCode.denied),
              )
            : Ok(upcoming),
      );
      final cubit = UpcomingSessionsCubit(get, watch);
      await cubit.load();
      await cubit.load();

      verify(() => watch()).called(2);
      await cubit.close();
    });

    test('closing releases the watch and no reload follows', () async {
      var loads = 0;
      when(() => get()).thenAnswer((_) async {
        loads++;
        return Ok(upcoming);
      });
      final cubit = UpcomingSessionsCubit(get, watch);
      await cubit.load();

      await cubit.close();
      changes.add(null);
      await pumpEventQueue();

      expect(changes.hasListener, isFalse);
      expect(loads, 1);
    });
  });
}
