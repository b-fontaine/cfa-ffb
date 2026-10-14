import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/manage_students/domain/club_overview.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/students_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/suggested_session_bloc.dart';
import 'package:billard_cfa/pages/suggested_session/presentation/suggested_session_page.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/widgets/roster_picker/presentation/roster_selection_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shared/ui/pump_ui.dart';

class _MockStudents extends MockBloc<StudentsEvent, StudentsState>
    implements StudentsBloc;

class _MockSuggested
    extends MockBloc<SuggestedSessionEvent, SuggestedSessionState>
    implements SuggestedSessionBloc;

void main() {
  final club = ClubOverview(
    groups: [
      GroupOverview(
        group: Group(
          id: const GroupId('g1'),
          seasonId: const SeasonId('s1'),
          name: 'Jeunes',
          audience: Audience.children,
        ),
        members: [
          StudentSummary(
            student: Student.enroll(
              id: const StudentId('lea'),
              firstName: 'Léa',
              audience: Audience.children,
              since: DateTime(2026, 9),
            ),
            validatedCount: 0,
            exerciseCount: 4,
            alertCount: 0,
          ),
        ],
      ),
    ],
    unassigned: const [],
  );

  Future<void> pump(WidgetTester tester, SuggestedSessionState state) async {
    final students = _MockStudents();
    final suggested = _MockSuggested();
    whenListen(
      students,
      const Stream<StudentsState>.empty(),
      initialState: StudentsState(status: StudentsStatus.ready, club: club),
    );
    whenListen(
      suggested,
      const Stream<SuggestedSessionState>.empty(),
      initialState: state,
    );
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpUi(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<StudentsBloc>.value(value: students),
          BlocProvider<SuggestedSessionBloc>.value(value: suggested),
          BlocProvider(
            create: (_) => RosterSelectionCubit(
              initialGroupId: const GroupId('g1'),
              initialAbsent: const {},
            ),
          ),
        ],
        child: SuggestedSessionPage(
          onOpenSource: (_) {},
          onRecord: (_, _, _, _) {},
          onOpenSheet: (_, _) {},
          onLaunch: (_, _, _) {},
          onPlan: (_, _) {},
          onAddStudents: () {},
        ),
      ),
    );
  }

  testWidgets('shows the loading state of the suggestion', (tester) async {
    await pump(
      tester,
      const SuggestedSessionState(status: SuggestedStatus.loading),
    );

    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets('shows the failure, such as an unreadable sheet catalogue', (
    tester,
  ) async {
    await pump(
      tester,
      const SuggestedSessionState(
        status: SuggestedStatus.failure,
        failure: InvariantViolation(InvariantCode.invalidSheet),
      ),
    );

    expect(
      find.text('Something went wrong. Check the data and try again.'),
      findsOneWidget,
    );
  });
}
