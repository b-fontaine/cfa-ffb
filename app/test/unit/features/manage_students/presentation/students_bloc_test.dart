import 'dart:async';

import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/features/manage_students/domain/club_overview.dart';
import 'package:billard_cfa/features/manage_students/domain/get_club_overview.dart';
import 'package:billard_cfa/features/manage_students/domain/watch_club_overview.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/students_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixed_clock.dart';
import '../../../../support/stream_log.dart';

class _MockGetClubOverview extends Mock implements GetClubOverview;

class _MockWatch extends Mock implements WatchClubOverview;

void main() {
  late _MockGetClubOverview overview;
  late _MockWatch watch;
  late StreamController<void> changes;
  final today = DateTime(2026, 10, 12);
  const club = ClubOverview(groups: [], unassigned: []);

  setUp(() {
    overview = _MockGetClubOverview();
    watch = _MockWatch();
    changes = StreamController<void>.broadcast();
    when(() => watch()).thenAnswer((_) => changes.stream);
  });

  tearDown(() => changes.close());

  StudentsBloc build() =>
      StudentsBloc(overview, watch, FixedClock(DateTime(2026, 10, 12, 18)));

  blocTest<StudentsBloc, StudentsState>(
    'loads the club of the day',
    build: () {
      when(() => overview(today: today))
          .thenAnswer((_) async => const Ok(club));
      return build();
    },
    act: (bloc) => bloc.add(const StudentsEvent.started()),
    expect: () => [
      const StudentsState(),
      const StudentsState(status: StudentsStatus.ready, club: club),
    ],
    verify: (_) => verify(() => overview(today: today)).called(1),
  );

  blocTest<StudentsBloc, StudentsState>(
    'reports a failure',
    build: () {
      when(() => overview(today: today)).thenAnswer(
        (_) async => const Err(InvariantViolation(InvariantCode.invalidRules)),
      );
      return build();
    },
    act: (bloc) => bloc.add(const StudentsEvent.started()),
    expect: () => [
      const StudentsState(),
      const StudentsState(
        status: StudentsStatus.failure,
        failure: InvariantViolation(InvariantCode.invalidRules),
      ),
    ],
  );

  blocTest<StudentsBloc, StudentsState>(
    'shows the loading state again while refreshing',
    build: () {
      when(() => overview(today: today))
          .thenAnswer((_) async => const Ok(club));
      return build();
    },
    seed: () => const StudentsState(status: StudentsStatus.ready, club: club),
    act: (bloc) => bloc.add(const StudentsEvent.refreshed()),
    expect: () => [
      const StudentsState(club: club),
      const StudentsState(status: StudentsStatus.ready, club: club),
    ],
  );

  group('live updates', () {
    final other = ClubOverview(
      groups: [
        GroupOverview(
          group: Group(
            id: const GroupId('g1'),
            seasonId: const SeasonId('season'),
            name: 'Mardi',
            audience: Audience.children,
          ),
          members: const [],
        ),
      ],
      unassigned: const [],
    );

    test('watches the club once started, once only', () async {
      when(() => overview(today: today))
          .thenAnswer((_) async => const Ok(club));
      final bloc = build()
        ..add(const StudentsEvent.started())
        ..add(const StudentsEvent.started());
      await pumpEventQueue();

      verify(() => watch()).called(1);
      expect(changes.hasListener, isTrue);
      await bloc.close();
    });

    test('reloads in place, without the loading state, on a change', () async {
      var calls = 0;
      when(() => overview(today: today))
          .thenAnswer((_) async => Ok(calls++ == 0 ? club : other));
      final bloc = build();
      final log = StreamLog(bloc.stream);
      bloc.add(const StudentsEvent.started());
      await log.settle();

      changes.add(null);
      await log.settle();

      expect(
        [for (final s in log.values) s.status],
        [StudentsStatus.loading, StudentsStatus.ready, StudentsStatus.ready],
      );
      expect(log.last.club, other);
      await log.cancel();
      await bloc.close();
    });

    test('a change that cannot be read shows the failure', () async {
      var failing = false;
      when(() => overview(today: today)).thenAnswer(
        (_) async => failing
            ? const Err<ClubOverview>(ServiceFailure(ServiceFailureCode.denied))
            : const Ok(club),
      );
      final bloc = build();
      final log = StreamLog(bloc.stream);
      bloc.add(const StudentsEvent.started());
      await log.settle();

      failing = true;
      changes.addError(const ServiceFailure(ServiceFailureCode.denied));
      await log.settle();

      expect(log.last.status, StudentsStatus.failure);
      await log.cancel();
      await bloc.close();
    });

    test('a retry after a failure reopens the watch', () async {
      var calls = 0;
      when(() => overview(today: today)).thenAnswer(
        (_) async => calls++ == 0
            ? const Err<ClubOverview>(ServiceFailure(ServiceFailureCode.denied))
            : const Ok(club),
      );
      final bloc = build()..add(const StudentsEvent.started());
      await pumpEventQueue();

      bloc.add(const StudentsEvent.refreshed());
      await pumpEventQueue();

      verify(() => watch()).called(2);
      await bloc.close();
    });

    test('closing releases the watch', () async {
      when(() => overview(today: today))
          .thenAnswer((_) async => const Ok(club));
      final bloc = build()..add(const StudentsEvent.started());
      await pumpEventQueue();

      await bloc.close();

      expect(changes.hasListener, isFalse);
    });
  });
}
