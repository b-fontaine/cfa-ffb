import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/manage_students/domain/club_overview.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/students_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/open_session_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/session_date_cubit.dart';
import 'package:billard_cfa/pages/record_setup/presentation/record_setup_page.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/widgets/roster_picker/presentation/roster_selection_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../shared/ui/pump_ui.dart';

class _MockStudents extends MockBloc<StudentsEvent, StudentsState>
    implements StudentsBloc;

class _MockOpen extends MockBloc<OpenSessionEvent, OpenSessionState>
    implements OpenSessionBloc;

void main() {
  final today = DateTime(2026, 10, 12);
  final since = DateTime(2026, 9);

  StudentSummary summary(String id, String name) => StudentSummary(
    student: Student.enroll(
      id: StudentId(id),
      firstName: name,
      audience: Audience.children,
      since: since,
    ),
    validatedCount: 0,
    exerciseCount: 4,
    alertCount: 0,
  );

  final club = ClubOverview(
    groups: [
      GroupOverview(
        group: Group(
          id: const GroupId('g1'),
          seasonId: const SeasonId('s1'),
          name: 'Jeunes',
          audience: Audience.children,
        ),
        members: [summary('lea', 'Léa'), summary('hugo', 'Hugo')],
      ),
    ],
    unassigned: const [],
  );

  late _MockStudents students;
  late _MockOpen open;

  setUpAll(() {
    registerFallbackValue(const StudentsEvent.refreshed());
    registerFallbackValue(
      OpenSessionEvent.requested(
        groupId: const GroupId('g'),
        date: DateTime(2026),
        present: const {},
      ),
    );
  });

  setUp(() {
    students = _MockStudents();
    open = _MockOpen();
  });

  Future<List<OpenedRecord>> pump(
    WidgetTester tester, {
    required StudentsState studentsState,
    OpenSessionState openState = const OpenSessionState(),
    Stream<OpenSessionState>? openStates,
    Set<StudentId> absent = const {},
    DateTime? date,
    VoidCallback? onBackToGuide,
  }) async {
    whenListen(
      students,
      const Stream<StudentsState>.empty(),
      initialState: studentsState,
    );
    whenListen(
      open,
      openStates ?? const Stream<OpenSessionState>.empty(),
      initialState: openState,
    );
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <OpenedRecord>[];
    await pumpUi(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<StudentsBloc>.value(value: students),
          BlocProvider<OpenSessionBloc>.value(value: open),
          BlocProvider(
            create: (_) => RosterSelectionCubit(
              initialGroupId: const GroupId('g1'),
              initialAbsent: absent,
            ),
          ),
          BlocProvider(create: (_) => SessionDateCubit(date ?? today)),
        ],
        child: RecordSetupPage(
          today: today,
          onOpened: opened.add,
          onAddStudents: () {},
          mainBlockId: 'demi-bille',
          recallBlockId: 'bille-pleine',
          sheetId: SheetId('demi-bille-2'),
          onBackToGuide: onBackToGuide,
        ),
      ),
    );
    return opened;
  }

  StudentsState ready() =>
      StudentsState(status: StudentsStatus.ready, club: club);

  testWidgets('shows the failure to read the club and retries', (tester) async {
    await pump(
      tester,
      studentsState: const StudentsState(
        status: StudentsStatus.failure,
        failure: InvariantViolation(InvariantCode.invalidRules),
      ),
    );

    await tester.tap(find.text('Retry'));

    verify(() => students.add(const StudentsEvent.refreshed())).called(1);
  });

  testWidgets('starts with the absentees and the date it was given', (
    tester,
  ) async {
    await pump(
      tester,
      studentsState: ready(),
      absent: {const StudentId('hugo')},
      date: DateTime(2026, 10, 5),
    );

    CheckboxListTile tile(String name) => tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, name),
    );
    expect(tile('Léa').value, isTrue);
    expect(tile('Hugo').value, isFalse);
    expect(find.text('Mon, Oct 5'), findsOneWidget);
  });

  testWidgets('opens the session with the chosen present students', (
    tester,
  ) async {
    await pump(
      tester,
      studentsState: ready(),
      absent: {const StudentId('hugo')},
    );

    await tester.tap(find.text('Open the session'));

    final captured =
        verify(() => open.add(captureAny())).captured.single
            as OpenSessionRequested;
    expect(captured.groupId, const GroupId('g1'));
    expect(captured.present, {const StudentId('lea')});
    expect(captured.date, today);
    expect(captured.mainBlockId, 'demi-bille');
    expect(captured.recallBlockId, 'bille-pleine');
    expect(captured.sheetId?.value, 'demi-bille-2');
  });

  testWidgets('reports the opened session with the choice that opened it', (
    tester,
  ) async {
    final record = SessionRecord(
      id: const SessionId('r1'),
      groupId: const GroupId('g1'),
      seasonId: const SeasonId('s1'),
      date: DateTime(2026, 10, 5),
      audience: Audience.children,
      present: const {StudentId('lea')},
    );
    final opened = await pump(
      tester,
      studentsState: ready(),
      absent: {const StudentId('hugo')},
      openStates: Stream.value(
        OpenSessionState(status: OpenSessionStatus.opened, session: record),
      ),
    );
    await tester.pump();

    expect(opened, hasLength(1));
    expect(opened.single.id, const SessionId('r1'));
    expect(opened.single.group, const GroupId('g1'));
    expect(opened.single.date, DateTime(2026, 10, 5));
    expect(opened.single.absent, {const StudentId('hugo')});
  });

  testWidgets('says why the session could not be opened', (tester) async {
    await pump(
      tester,
      studentsState: ready(),
      openState: const OpenSessionState(
        status: OpenSessionStatus.failure,
        failure: InvariantViolation(InvariantCode.noStudents),
      ),
    );

    expect(find.text('Select at least one student.'), findsOneWidget);
  });

  testWidgets('goes back to the guide without opening anything', (
    tester,
  ) async {
    var back = 0;
    await pump(tester, studentsState: ready(), onBackToGuide: () => back++);

    await tester.tap(find.text('Back to the guided session'));

    expect(back, 1);
    verifyNever(() => open.add(any()));
  });

  testWidgets('offers no way back to the guide by default', (tester) async {
    await pump(tester, studentsState: ready());

    expect(find.text('Back to the guided session'), findsNothing);
  });

  testWidgets('changes the date to the exact day picked', (tester) async {
    await pump(tester, studentsState: ready());

    await tester.tap(find.text('Change the date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Wed, Oct 7'), findsOneWidget);
  });

  testWidgets('keeps the date when the picker is dismissed', (tester) async {
    await pump(tester, studentsState: ready());

    await tester.tap(find.text('Change the date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Mon, Oct 12'), findsOneWidget);
  });
}
