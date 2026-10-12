import 'package:billard_cfa/features/manage_students/domain/club_overview.dart';
import 'package:billard_cfa/features/manage_students/domain/get_club_overview.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/students_bloc.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixed_clock.dart';

class _MockGetClubOverview extends Mock implements GetClubOverview;

void main() {
  late _MockGetClubOverview overview;
  final today = DateTime(2026, 10, 12);
  const club = ClubOverview(groups: [], unassigned: []);

  setUp(() => overview = _MockGetClubOverview());

  StudentsBloc build() =>
      StudentsBloc(overview, FixedClock(DateTime(2026, 10, 12, 18)));

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
}
